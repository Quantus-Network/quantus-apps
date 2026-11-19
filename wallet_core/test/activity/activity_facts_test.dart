import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_facts.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

import '../fakes.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final me = makeAccount(1).accountId;
  final other = makeAccount(2).accountId;
  final recipient = makeAccount(3).accountId;
  final msig = makeAccount(4).accountId;
  final at = DateTime.utc(2026, 9, 6);

  ActivityFacts factsOf(TransactionEvent tx) => activityFactsOf(tx, accountId: me, l10n: l10n);

  TransferEvent transfer({required String from, required String to}) => TransferEvent(
    id: 'tx',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: at,
    fee: BigInt.one,
    extrinsicHash: '0x9cbe',
    blockNumber: 1,
    blockHash: '0xblock',
  );

  ReversibleTransferEvent reversible({required String from}) => ReversibleTransferEvent(
    id: 'reversible',
    from: from,
    to: from == me ? other : me,
    amount: BigInt.from(300),
    timestamp: at,
    txId: '0xtxid',
    status: ReversibleTransferStatus.SCHEDULED,
    scheduledAt: at.add(const Duration(days: 1)),
    blockNumber: 1,
    blockHash: '0xblock',
  );

  WormholeTransferEvent private({required String from, required String to}) => WormholeTransferEvent(
    id: 'wormhole',
    from: from,
    to: to,
    amount: BigInt.from(300),
    timestamp: at,
    fee: BigInt.zero,
    extrinsicHash: '0xwormhole',
    blockNumber: 1,
  );

  final multisigFact = ActivityAddressFact(ActivityFactKind.multisig, msig);
  final toRecipient = ActivityPartyFact(ActivityFactKind.to, ActivityAccount(recipient, isRecipient: true));
  final moves = ActivityAmountFact(ActivityFactKind.transferAmount, BigInt.from(500));
  ActivityAmountFact fee(int tokens) => ActivityAmountFact(ActivityFactKind.networkFee, BigInt.from(tokens));

  group('a transfer', () {
    test('sent: what it sent, to whom, when, its fee and its hash', () {
      expect(
        factsOf(transfer(from: me, to: other)),
        ActivityFacts(
          amount: BigInt.from(300),
          highlight: ActivityHighlight.none,
          facts: [
            ActivityPartyFact(ActivityFactKind.to, ActivityAccount(other, isRecipient: true)),
            ActivityTimeFact(at),
            fee(1),
            const ActivityHashFact('0x9cbe'),
          ],
        ),
      );
    });

    test('received: what came in, from whom, when, the fee its sender paid and its hash', () {
      expect(
        factsOf(transfer(from: other, to: me)),
        ActivityFacts(
          amount: BigInt.from(300),
          highlight: ActivityHighlight.arriving,
          facts: [
            ActivityPartyFact(ActivityFactKind.from, ActivityAccount(other, isRecipient: false)),
            ActivityTimeFact(at),
            fee(1),
            const ActivityHashFact('0x9cbe'),
          ],
        ),
      );
    });

    test('sending: its fee once known, its hash once broadcast', () {
      PendingTransactionEvent sending({BigInt? fee, String? hash}) => PendingTransactionEvent(
        tempId: 'pending',
        from: me,
        to: other,
        amount: BigInt.from(300),
        timestamp: at,
        fee: fee,
        extrinsicHash: hash,
      );
      final toOther = ActivityPartyFact(ActivityFactKind.to, ActivityAccount(other, isRecipient: true));

      expect(factsOf(sending()).facts, [toOther, ActivityTimeFact(at)]);
      expect(factsOf(sending(fee: BigInt.zero)).facts, [toOther, ActivityTimeFact(at)]);
      expect(factsOf(sending(fee: BigInt.one, hash: '0xsending')).facts, [
        toOther,
        ActivityTimeFact(at),
        fee(1),
        const ActivityHashFact('0xsending'),
      ]);
    });

    test('scheduled to run, sent or received', () {
      expect(
        factsOf(reversible(from: me)),
        ActivityFacts(
          amount: BigInt.from(300),
          highlight: ActivityHighlight.none,
          facts: [
            ActivityPartyFact(ActivityFactKind.to, ActivityAccount(other, isRecipient: true)),
            ActivityTimeFact(at),
          ],
        ),
      );
      expect(
        factsOf(reversible(from: other)),
        ActivityFacts(
          amount: BigInt.from(300),
          highlight: ActivityHighlight.arriving,
          facts: [
            ActivityPartyFact(ActivityFactKind.from, ActivityAccount(other, isRecipient: false)),
            ActivityTimeFact(at),
          ],
        ),
      );
    });
  });

  group('a private transfer', () {
    test('received: its sender is not known, so it is "Encrypted"', () {
      expect(factsOf(private(from: other, to: me)).facts, [
        const ActivityPartyFact(ActivityFactKind.from, ActivityEncryptedSender()),
        ActivityTimeFact(at),
        const ActivityHashFact('0xwormhole'),
      ]);
    });

    test('sent in a batch with other transfers: its recipient is the aggregated batch', () {
      expect(factsOf(private(from: me, to: '')).facts, [
        const ActivityPartyFact(ActivityFactKind.to, ActivityAggregatedBatch()),
        ActivityTimeFact(at),
        const ActivityHashFact('0xwormhole'),
      ]);
    });
  });

  group('a multisig proposal', () {
    final made = [
      multisigFact,
      toRecipient,
      ActivityAmountFact(ActivityFactKind.proposalFee, BigInt.one),
      ActivityAmountFact(ActivityFactKind.deposit, BigInt.from(2)),
      fee(3),
    ];

    test('being proposed: what it moves, its costs, when, and its hash', () {
      final proposing = PendingMultisigProposalEvent.create(
        msig: MultisigAccount(
          name: 'Team',
          accountId: msig,
          signers: [me, other],
          threshold: 2,
          nonce: BigInt.zero,
          myMemberAccountId: me,
        ),
        proposerId: me,
        recipient: recipient,
        amount: BigInt.from(500),
        expiryBlock: 1000,
        fee: BigInt.from(3),
        deposit: BigInt.from(2),
        palletFee: BigInt.one,
      ).copyWith(extrinsicHash: '0xproposing');

      expect(
        factsOf(proposing),
        ActivityFacts(
          amount: BigInt.from(500),
          highlight: ActivityHighlight.none,
          facts: [...made, ActivityTimeFact(proposing.timestamp), const ActivityHashFact('0xproposing')],
        ),
      );
    });

    test('proposed', () {
      expect(
        factsOf(
          MultisigProposalCreatedEvent(
            id: 'created',
            proposerId: me,
            multisigAddress: msig,
            recipient: recipient,
            amount: BigInt.from(500),
            palletFee: BigInt.one,
            deposit: BigInt.from(2),
            timestamp: at,
            blockNumber: 1,
            blockHash: '0xblock',
            fee: BigInt.from(3),
            extrinsicHash: '0xcreated',
          ),
        ),
        ActivityFacts(
          amount: BigInt.from(500),
          highlight: ActivityHighlight.none,
          facts: [...made, ActivityTimeFact(at), const ActivityHashFact('0xcreated')],
        ),
      );
    });

    MultisigProposalApprovedEvent approved({BigInt? fee}) => MultisigProposalApprovedEvent(
      id: 'approved',
      approverId: me,
      multisigAddress: msig,
      recipient: recipient,
      amount: BigInt.from(500),
      proposalId: 4,
      approvalsCount: 2,
      timestamp: at,
      blockNumber: 1,
      blockHash: '0xblock',
      fee: fee,
      extrinsicHash: '0xapproved',
    );

    test('approved: its fee is the amount, and it says how many approved', () {
      expect(
        factsOf(approved(fee: BigInt.from(7))),
        ActivityFacts(
          amount: BigInt.from(7),
          highlight: ActivityHighlight.none,
          facts: [
            multisigFact,
            toRecipient,
            moves,
            const ActivityTextFact(ActivityFactKind.approvals, '2'),
            fee(7),
            ActivityTimeFact(at),
            const ActivityHashFact('0xapproved'),
          ],
        ),
      );
    });

    test('approved, its fee not known: no amount and no fee', () {
      expect(
        factsOf(approved()),
        ActivityFacts(
          amount: null,
          highlight: ActivityHighlight.none,
          facts: [
            multisigFact,
            toRecipient,
            moves,
            const ActivityTextFact(ActivityFactKind.approvals, '2'),
            ActivityTimeFact(at),
            const ActivityHashFact('0xapproved'),
          ],
        ),
      );
    });

    PendingMultisigExecutionEvent executing({BigInt? fee}) => PendingMultisigExecutionEvent.create(
      multisigAddress: msig,
      proposalId: 4,
      executorId: me,
      recipient: recipient,
      amount: BigInt.from(500),
      fee: fee,
    ).copyWith(extrinsicHash: '0xexecuting');

    test('executing: its fee is the amount, on its way out; no time until it is in a block', () {
      expect(
        factsOf(executing(fee: BigInt.from(6))),
        ActivityFacts(
          amount: BigInt.from(6),
          highlight: ActivityHighlight.leaving,
          facts: [multisigFact, toRecipient, moves, fee(6), const ActivityHashFact('0xexecuting')],
        ),
      );
      expect(
        factsOf(executing()),
        ActivityFacts(
          amount: null,
          highlight: ActivityHighlight.leaving,
          facts: [multisigFact, toRecipient, moves, const ActivityHashFact('0xexecuting')],
        ),
      );
    });

    test('executed', () {
      expect(
        factsOf(
          MultisigProposalExecutedEvent(
            id: 'executed',
            executorId: me,
            multisigAddress: msig,
            recipient: recipient,
            amount: BigInt.from(500),
            proposalId: 4,
            approvers: [me, other],
            result: 'ok',
            timestamp: at,
            blockNumber: 1,
            blockHash: '0xblock',
            fee: BigInt.from(6),
            extrinsicHash: '0xexecuted',
          ),
        ),
        ActivityFacts(
          amount: BigInt.from(6),
          highlight: ActivityHighlight.none,
          facts: [multisigFact, toRecipient, moves, fee(6), ActivityTimeFact(at), const ActivityHashFact('0xexecuted')],
        ),
      );
    });

    test('cancelling', () {
      expect(
        factsOf(
          PendingMultisigCancellationEvent.create(
            multisigAddress: msig,
            proposalId: 4,
            proposerId: me,
            recipient: recipient,
            amount: BigInt.from(500),
            fee: BigInt.from(5),
          ).copyWith(extrinsicHash: '0xcancelling'),
        ),
        ActivityFacts(
          amount: BigInt.from(5),
          highlight: ActivityHighlight.leaving,
          facts: [multisigFact, toRecipient, moves, fee(5), const ActivityHashFact('0xcancelling')],
        ),
      );
    });

    test('cancelled', () {
      expect(
        factsOf(
          MultisigProposalCancelledEvent(
            id: 'cancelled',
            proposerId: me,
            multisigAddress: msig,
            recipient: recipient,
            amount: BigInt.from(500),
            proposalId: 4,
            timestamp: at,
            blockNumber: 1,
            blockHash: '0xblock',
            fee: BigInt.from(5),
            extrinsicHash: '0xcancelled',
          ),
        ),
        ActivityFacts(
          amount: BigInt.from(5),
          highlight: ActivityHighlight.none,
          facts: [
            multisigFact,
            toRecipient,
            moves,
            fee(5),
            ActivityTimeFact(at),
            const ActivityHashFact('0xcancelled'),
          ],
        ),
      );
    });
  });

  group('a multisig made', () {
    List<ActivityFact> made({required String creator}) => [
      ActivityAddressFact(ActivityFactKind.newMultisig, msig),
      ActivityTextFact(ActivityFactKind.threshold, l10n.activityDetailMultisigThresholdValue(2, 2)),
      const ActivityTextFact(ActivityFactKind.signers, '2'),
      ActivityAddressFact(ActivityFactKind.creator, creator),
      ActivityAmountFact(ActivityFactKind.creationFee, BigInt.from(4)),
      fee(3),
      ActivityTimeFact(at),
    ];

    MultisigCreatedEvent created({required String creator}) => MultisigCreatedEvent(
      id: 'multisig',
      creatorId: creator,
      multisigAddress: msig,
      threshold: 2,
      nonce: BigInt.zero,
      signers: [me, other],
      palletFee: BigInt.from(4),
      networkFee: BigInt.from(3),
      timestamp: at,
      blockNumber: 1,
      blockHash: '0xblock',
      extrinsicHash: '0xmultisig',
    );

    test('being created by this account: what it costs, on its way out; no hash yet', () {
      expect(
        factsOf(
          PendingMultisigCreationEvent(
            tempId: 'creating',
            creatorId: me,
            multisigAddress: msig,
            threshold: 2,
            nonce: BigInt.zero,
            signers: [me, other],
            palletFee: BigInt.from(4),
            networkFee: BigInt.from(3),
            timestamp: at,
            extrinsicHash: '0xcreating',
          ),
        ),
        ActivityFacts(
          amount: BigInt.from(7),
          highlight: ActivityHighlight.leaving,
          facts: made(creator: me),
        ),
      );
    });

    test('created by this account: what it cost', () {
      expect(
        factsOf(created(creator: me)),
        ActivityFacts(
          amount: BigInt.from(7),
          highlight: ActivityHighlight.none,
          facts: [
            ...made(creator: me),
            const ActivityHashFact('0xmultisig'),
          ],
        ),
      );
    });

    test('created by another signer: it cost this account nothing', () {
      expect(
        factsOf(created(creator: other)),
        ActivityFacts(
          amount: null,
          highlight: ActivityHighlight.none,
          facts: [
            ...made(creator: other),
            const ActivityHashFact('0xmultisig'),
          ],
        ),
      );
    });
  });

  test('a mining reward: what was received, from "Mining reward", when', () {
    final facts = factsOf(
      MinerRewardEvent(
        id: 'reward',
        miner: me,
        reward: BigInt.from(9),
        timestamp: at,
        blockNumber: 1,
        blockHash: '0xrewardblock',
      ),
    );

    expect((facts.amount, facts.highlight), (BigInt.from(9), ActivityHighlight.arriving));
    expect(facts.facts, hasLength(2));
    expect(
      facts.facts.first,
      isA<ActivityPartyFact>()
          .having((fact) => fact.kind, 'kind', ActivityFactKind.from)
          .having(
            (fact) => fact.who,
            'who',
            isA<ActivityUnnamedCounterparty>().having((who) => who.name(l10n), 'name', l10n.activitySenderMiningReward),
          ),
    );
    expect(facts.facts.last, ActivityTimeFact(at));
  });
}
