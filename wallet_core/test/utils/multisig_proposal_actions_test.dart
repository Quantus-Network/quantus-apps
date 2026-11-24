import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/multisig_proposal_actions.dart';

import '../fakes.dart';

final _one = makeAccount(1);
final _two = makeAccount(2);
final _three = makeAccount(3);

/// Three signers, two needed; this device's member is the first.
final _msig = MultisigAccount(
  name: 'Msig',
  accountId: 'qzmsig${'x' * 40}',
  signers: [_one.accountId, _two.accountId, _three.accountId],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: _one.accountId,
);

final _transferBytes = Uint8List.fromList(
  const balances_pallet.Txs()
      .transferAllowDeath(
        dest: multi_address.MultiAddress.values.id(Uint8List.fromList(List.filled(32, 0xBB))),
        value: BigInt.from(1000000000000),
      )
      .encode(),
);

/// The chain is at block 100.
const _currentBlock = 100;

MultisigProposal _proposal({
  MultisigProposalStatus status = MultisigProposalStatus.active,
  List<String> approvals = const [],
  String? proposer,
  int expiryBlock = 1000,
  Uint8List? callRaw,
}) => MultisigProposal(
  entityId: 'p1',
  id: 1,
  multisigAddress: _msig.accountId,
  proposer: proposer ?? _three.accountId,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  pallet: 'Balances',
  call: 'transfer_allow_death',
  recipient: 'qzbob${'x' * 40}',
  amount: BigInt.from(1000000000000),
  callRaw: callRaw ?? _transferBytes,
  expiryBlock: expiryBlock,
  approvals: approvals,
  deposit: BigInt.zero,
  status: status,
  threshold: _msig.threshold,
  signerCount: _msig.signers.length,
);

/// Approved by the two signers this wallet does not hold as `_one`.
MultisigProposal _ready({int expiryBlock = 1000, String? proposer}) => _proposal(
  status: MultisigProposalStatus.approved,
  approvals: [_two.accountId, _three.accountId],
  expiryBlock: expiryBlock,
  proposer: proposer,
);

PendingMultisigApprovalEvent _approving(Account approver) => PendingMultisigApprovalEvent.create(
  multisigAddress: _msig.accountId,
  proposalId: 1,
  approverId: approver.accountId,
);

final _executing = PendingMultisigExecutionEvent.create(
  multisigAddress: _msig.accountId,
  proposalId: 1,
  executorId: _one.accountId,
  recipient: 'qzbob${'x' * 40}',
  amount: BigInt.one,
);

final _cancelling = PendingMultisigCancellationEvent.create(
  multisigAddress: _msig.accountId,
  proposalId: 1,
  proposerId: _one.accountId,
  recipient: 'qzbob${'x' * 40}',
  amount: BigInt.one,
);

ProposalActions _actions(
  MultisigProposal proposal, {
  List<Account>? accounts,
  List<PendingMultisigApprovalEvent> approvals = const [],
  List<PendingMultisigExecutionEvent> executions = const [],
  List<PendingMultisigCancellationEvent> cancellations = const [],
}) => proposalActionsOf(
  msig: _msig,
  proposal: proposal,
  accounts: accounts ?? [_one],
  currentBlock: _currentBlock,
  pendingApprovals: approvals,
  pendingExecutions: executions,
  pendingCancellations: cancellations,
);

ProposalOpen _open(ProposalActions actions) {
  expect(actions, isA<ProposalOpen>());
  return actions as ProposalOpen;
}

List<String> _ids(List<Account> accounts) => accounts.map((a) => a.accountId).toList();

void main() {
  group('over', () {
    test('an undecodable call: only Done, and no note', () {
      final actions = _actions(_proposal(callRaw: Uint8List.fromList([..._transferBytes, 0x00])));

      expect(actions, isA<ProposalOver>());
      expect(actions.note, isNull);
    });

    for (final (status, note) in [
      (MultisigProposalStatus.executed, ProposalActionNote.executed),
      (MultisigProposalStatus.cancelled, ProposalActionNote.cancelled),
    ]) {
      test('${status.name}: only Done, with its note, even for the proposer', () {
        final actions = _actions(_proposal(status: status, proposer: _one.accountId));

        expect(actions, isA<ProposalOver>());
        expect(actions.note, note);
      });
    }

    test('every local signer approved and it is not ready: only Done, with the already-signed note', () {
      final actions = _actions(_proposal(approvals: [_one.accountId]));

      expect(actions, isA<ProposalOver>());
      expect(actions.note, ProposalActionNote.alreadySigned);
    });
  });

  group('approve', () {
    test('one local signer still to approve: Approve offered, by that signer', () {
      final actions = _open(_actions(_proposal()));

      expect(actions.primary, ProposalPrimaryAction.approve);
      expect(actions.primaryState, ProposalActionState.offered);
      expect(_ids(actions.eligibleApprovers), [_one.accountId]);
      expect(actions.note, isNull);
    });

    test('two local signers still to approve: Approve offered, by either', () {
      final actions = _open(_actions(_proposal(), accounts: [_one, _two]));

      expect(actions.primaryState, ProposalActionState.offered);
      expect(_ids(actions.eligibleApprovers), [_one.accountId, _two.accountId]);
    });

    test('one local signer approving and another still to: Approve offered, by the other only', () {
      final actions = _open(_actions(_proposal(), accounts: [_one, _two], approvals: [_approving(_one)]));

      expect(actions.primaryState, ProposalActionState.offered);
      expect(_ids(actions.eligibleApprovers), [_two.accountId]);
      expect(actions.note, isNull);
    });

    test('the only local signer approving: Approve in flight, with the approving note', () {
      final actions = _open(_actions(_proposal(), approvals: [_approving(_one)]));

      expect(actions.primary, ProposalPrimaryAction.approve);
      expect(actions.primaryState, ProposalActionState.inFlight);
      expect(actions.note, ProposalActionNote.approving);
    });

    test('a cancellation from this device under way: Approve unavailable, with the cancelling note', () {
      final actions = _open(_actions(_proposal(proposer: _one.accountId), cancellations: [_cancelling]));

      expect(actions.primaryState, ProposalActionState.unavailable);
      expect(actions.note, ProposalActionNote.cancelling);
    });

    test('expired: Approve unavailable, with the unavailable note', () {
      final actions = _open(_actions(_proposal(expiryBlock: _currentBlock)));

      expect(actions.primaryState, ProposalActionState.unavailable);
      expect(actions.note, ProposalActionNote.approveUnavailable);
    });

    test('no signer of it in this wallet: Approve unavailable, with the unavailable note', () {
      final actions = _open(_actions(_proposal(), accounts: [makeAccount(9)]));

      expect(actions.primaryState, ProposalActionState.unavailable);
      expect(actions.eligibleApprovers, isEmpty);
      expect(actions.note, ProposalActionNote.approveUnavailable);
    });
  });

  group('execute', () {
    test('approved: Execute offered, and no note', () {
      final actions = _open(_actions(_ready()));

      expect(actions.primary, ProposalPrimaryAction.execute);
      expect(actions.primaryState, ProposalActionState.offered);
      expect(actions.note, isNull);
    });

    test('an approval from this device under way: Execute unavailable, with the approving note', () {
      final actions = _open(_actions(_ready(), approvals: [_approving(_one)]));

      expect(actions.primaryState, ProposalActionState.unavailable);
      expect(actions.note, ProposalActionNote.approving);
    });

    test('a cancellation from this device under way: Execute unavailable, with the cancelling note', () {
      // Only its proposer cancels it.
      final actions = _open(_actions(_ready(proposer: _one.accountId), cancellations: [_cancelling]));

      expect(actions.primaryState, ProposalActionState.unavailable);
      expect(actions.note, ProposalActionNote.cancelling);
    });

    test('an execution from this device under way: Execute in flight, with the executing note', () {
      final actions = _open(_actions(_ready(), executions: [_executing]));

      expect(actions.primary, ProposalPrimaryAction.execute);
      expect(actions.primaryState, ProposalActionState.inFlight);
      expect(actions.note, ProposalActionNote.executing);
    });

    test('expired: Execute unavailable, with the execute-unavailable note', () {
      final actions = _open(_actions(_ready(expiryBlock: _currentBlock)));

      expect(actions.primaryState, ProposalActionState.unavailable);
      expect(actions.note, ProposalActionNote.executeUnavailable);
    });

    test('the member and another signer here: Execute offered, by either, the member first', () {
      final actions = _open(_actions(_ready(), accounts: [_two, _one]));

      expect(actions.primaryState, ProposalActionState.offered);
      expect(_ids(actions.executors), [_one.accountId, _two.accountId]);
    });

    test('the member not here but another signer is: Execute offered, by that signer', () {
      final actions = _open(_actions(_ready(), accounts: [_two]));

      expect(actions.primaryState, ProposalActionState.offered);
      expect(_ids(actions.executors), [_two.accountId]);
    });

    test('an execution under way from a signer that is not the member: Execute in flight, with its note', () {
      final actions = _open(
        _actions(
          _ready(),
          accounts: [_one, _two],
          executions: [
            PendingMultisigExecutionEvent.create(
              multisigAddress: _msig.accountId,
              proposalId: 1,
              executorId: _two.accountId,
              recipient: 'qzbob${'x' * 40}',
              amount: BigInt.one,
            ),
          ],
        ),
      );

      expect(actions.primaryState, ProposalActionState.inFlight);
      expect(actions.note, ProposalActionNote.executing);
    });

    test('not ready: no one executes', () {
      expect(_open(_actions(_proposal(), accounts: [_one, _two])).executors, isEmpty);
    });

    test('no signer of it in this wallet: Execute unavailable, with the execute-unavailable note', () {
      final actions = _open(_actions(_ready(), accounts: [makeAccount(9)]));

      expect(actions.primaryState, ProposalActionState.unavailable);
      expect(actions.note, ProposalActionNote.executeUnavailable);
    });
  });

  group('cancel', () {
    test('the proposer is this device\'s member: Cancel offered, by the member', () {
      final actions = _open(_actions(_proposal(proposer: _one.accountId)));

      expect(actions.cancel, ProposalActionState.offered);
      expect(actions.canceller?.accountId, _one.accountId);
    });

    test('the proposer is another signer in this wallet: Cancel offered, by that signer', () {
      final actions = _open(_actions(_proposal(proposer: _two.accountId), accounts: [_one, _two]));

      expect(actions.cancel, ProposalActionState.offered);
      expect(actions.canceller?.accountId, _two.accountId);
    });

    test('the proposer is a signer not in this wallet: no Cancel', () {
      final actions = _open(_actions(_proposal(proposer: _two.accountId), accounts: [_one]));

      expect(actions.cancel, isNull);
      expect(actions.canceller, isNull);
    });

    test('a cancellation under way from a proposer that is not the member: Cancel in flight, with its note', () {
      final actions = _open(
        _actions(
          _proposal(proposer: _two.accountId),
          accounts: [_one, _two],
          cancellations: [
            PendingMultisigCancellationEvent.create(
              multisigAddress: _msig.accountId,
              proposalId: 1,
              proposerId: _two.accountId,
              recipient: 'qzbob${'x' * 40}',
              amount: BigInt.one,
            ),
          ],
        ),
      );

      expect(actions.cancel, ProposalActionState.inFlight);
      expect(actions.note, ProposalActionNote.cancelling);
    });

    test('its cancellation under way: Cancel in flight', () {
      final actions = _open(_actions(_proposal(proposer: _one.accountId), cancellations: [_cancelling]));

      expect(actions.cancel, ProposalActionState.inFlight);
    });

    test('an approval from this device under way: Cancel unavailable', () {
      final actions = _open(
        _actions(
          _proposal(proposer: _one.accountId),
          accounts: [_one, _two],
          approvals: [_approving(_two)],
        ),
      );

      expect(actions.cancel, ProposalActionState.unavailable);
    });

    test('expired: Cancel unavailable', () {
      final actions = _open(_actions(_proposal(proposer: _one.accountId, expiryBlock: _currentBlock)));

      expect(actions.cancel, ProposalActionState.unavailable);
    });
  });
}
