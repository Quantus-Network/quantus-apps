import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/multisig_proposal_polling_service.dart';

import '../fakes.dart';

/// An indexer that has the proposal created by a transaction once [created]
/// is set.
class _FakeChainHistoryService extends Fake implements ChainHistoryService {
  MultisigProposalCreatedEvent? created;

  /// The hashes asked for.
  final searches = <String>[];

  @override
  Future<MultisigProposalCreatedEvent?> searchProposalCreatedByExtrinsicHash({required String extrinsicHash}) async {
    searches.add(extrinsicHash);
    return created;
  }
}

void main() {
  const hash = '0xproposal';
  final member = makeAccount(1);
  final msig = MultisigAccount(
    name: 'Msig',
    accountId: 'qzmsig${'x' * 40}',
    signers: [member.accountId, makeAccount(2).accountId],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: member.accountId,
  );
  late _FakeChainHistoryService indexer;
  late ProviderContainer container;
  late PendingMultisigProposalEvent pending;

  SendConfirmation confirmation() => container.read(multisigProposalConfirmationProvider(hash));

  /// A proposal just broadcast: listed as pending, and watched for.
  void broadcast() {
    indexer = _FakeChainHistoryService();
    container = ProviderContainer(
      overrides: [...WalletTestBed().overrides, chainHistoryServiceProvider.overrideWithValue(indexer)],
    );
    addTearDown(container.dispose);
    pending = PendingMultisigProposalEvent.create(
      msig: msig,
      proposerId: member.accountId,
      recipient: makeAccount(3).accountId,
      amount: BigInt.from(5),
      expiryBlock: 1000,
    ).copyWith(extrinsicHash: hash);
    container.read(pendingMultisigProposalsProvider.notifier).add(pending);
    container.read(multisigProposalPollingServiceProvider).startPolling(msig, pending);
  }

  testWidgets('a proposal is pending while the indexer does not have it, and confirmed once it does', (tester) async {
    broadcast();
    await tester.pump(const Duration(seconds: 12));

    expect(indexer.searches, isNotEmpty);
    expect(confirmation(), SendConfirmation.pending);

    indexer.created = MultisigProposalCreatedEvent(
      id: 'event-1',
      proposerId: member.accountId,
      multisigAddress: msig.accountId,
      recipient: pending.recipient,
      amount: pending.amount,
      palletFee: BigInt.zero,
      deposit: BigInt.zero,
      timestamp: DateTime.utc(2026),
      blockNumber: 7,
      blockHash: '0xblock',
      extrinsicHash: hash,
    );
    await tester.pump(const Duration(seconds: 5));

    expect(confirmation(), SendConfirmation.confirmed);
    expect(container.read(pendingMultisigProposalsProvider), isEmpty);
  });

  testWidgets('a proposal the indexer never has is unconfirmed once the wallet stops watching for it', (tester) async {
    broadcast();

    await tester.pump(const Duration(minutes: 4));
    expect(confirmation(), SendConfirmation.pending);

    await tester.pump(const Duration(minutes: 1, seconds: 10));

    expect(confirmation(), SendConfirmation.unconfirmed);
    expect(container.read(pendingMultisigProposalsProvider), isEmpty);
  });

  testWidgets('a proposal once created is known by its id, before the pending row goes', (tester) async {
    broadcast();
    String? createdWhenPendingWent;
    container.listen(pendingMultisigProposalsProvider, (_, next) {
      if (next.isEmpty) createdWhenPendingWent = container.read(multisigCreatedProposalIdProvider(hash));
    });

    indexer.created = MultisigProposalCreatedEvent(
      id: 'event-1',
      proposerId: member.accountId,
      multisigAddress: msig.accountId,
      recipient: pending.recipient,
      amount: pending.amount,
      palletFee: BigInt.zero,
      deposit: BigInt.zero,
      timestamp: DateTime.utc(2026),
      blockNumber: 7,
      blockHash: '0xblock',
      extrinsicHash: hash,
      proposal: MultisigProposal(
        entityId: 'proposal-entity-1',
        id: 4,
        multisigAddress: msig.accountId,
        proposer: member.accountId,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        pallet: 'Balances',
        call: 'transfer_allow_death',
        recipient: pending.recipient,
        amount: pending.amount,
        expiryBlock: 1000,
        approvals: [member.accountId],
        deposit: BigInt.zero,
        status: MultisigProposalStatus.active,
        threshold: 2,
        signerCount: 2,
      ),
    );
    await tester.pump(const Duration(seconds: 12));

    expect(container.read(pendingMultisigProposalsProvider), isEmpty);
    expect(container.read(multisigCreatedProposalIdProvider(hash)), 'proposal-entity-1');
    expect(createdWhenPendingWent, 'proposal-entity-1');
  });

  testWidgets('a proposal the wallet gave up on has no id', (tester) async {
    broadcast();
    await tester.pump(const Duration(minutes: 5, seconds: 10));

    expect(confirmation(), SendConfirmation.unconfirmed);
    expect(container.read(multisigCreatedProposalIdProvider(hash)), isNull);
  });

  testWidgets('what became of one proposal says nothing of another', (tester) async {
    broadcast();
    await tester.pump(const Duration(minutes: 5, seconds: 10));

    expect(container.read(multisigProposalConfirmationProvider('0xother')), SendConfirmation.pending);
  });
}
