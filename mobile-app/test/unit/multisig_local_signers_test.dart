import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/multisig_local_signers.dart';

Account _account(String id, {String name = 'A'}) =>
    Account(walletIndex: 0, index: 0, name: name, accountId: id);

MultisigAccount _msig({required List<String> signers, String myMember = 'signer-a'}) => MultisigAccount(
  name: 'Msig',
  accountId: 'msig-1',
  signers: signers,
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: myMember,
);

MultisigProposal _proposal({required List<String> approvals}) => MultisigProposal(
  entityId: 'proposal-1',
  id: 1,
  multisigAddress: 'msig-1',
  proposer: 'signer-a',
  createdAt: DateTime.utc(2024),
  updatedAt: DateTime.utc(2024),
  pallet: 'Balances',
  call: 'transfer_allow_death',
  recipient: 'recipient',
  amount: BigInt.from(100),
  expiryBlock: 999999,
  approvals: approvals,
  deposit: BigInt.zero,
  status: MultisigProposalStatus.active,
  threshold: 2,
  signerCount: 2,
);

void main() {
  group('localSignersForMultisig', () {
    test('returns only accounts that are multisig signers', () {
      final msig = _msig(signers: const ['signer-a', 'signer-b', 'signer-c']);
      final accounts = [_account('signer-a', name: 'A'), _account('other'), _account('signer-c', name: 'C')];

      final local = localSignersForMultisig(msig, accounts);

      expect(local.map((a) => a.accountId), ['signer-a', 'signer-c']);
    });

    test('returns empty when no local accounts match', () {
      final msig = _msig(signers: const ['signer-a', 'signer-b']);
      expect(localSignersForMultisig(msig, [_account('other')]), isEmpty);
    });
  });

  group('eligibleApproversForProposal', () {
    test('excludes accounts that already approved', () {
      final msig = _msig(signers: const ['signer-a', 'signer-b']);
      final accounts = [_account('signer-a'), _account('signer-b')];
      final proposal = _proposal(approvals: const ['signer-a']);

      final eligible = eligibleApproversForProposal(msig, proposal, accounts);

      expect(eligible.map((a) => a.accountId), ['signer-b']);
    });

    test('excludes accounts with a pending approval', () {
      final msig = _msig(signers: const ['signer-a', 'signer-b']);
      final accounts = [_account('signer-a'), _account('signer-b')];
      final proposal = _proposal(approvals: const []);

      final eligible = eligibleApproversForProposal(
        msig,
        proposal,
        accounts,
        pendingApproverIds: {'signer-a'},
      );

      expect(eligible.map((a) => a.accountId), ['signer-b']);
    });

    test('returns empty when every local signer has approved', () {
      final msig = _msig(signers: const ['signer-a', 'signer-b']);
      final accounts = [_account('signer-a'), _account('signer-b')];
      final proposal = _proposal(approvals: const ['signer-a', 'signer-b']);

      expect(eligibleApproversForProposal(msig, proposal, accounts), isEmpty);
    });
  });

  group('pendingApproverIdsForProposal', () {
    test('collects pending approvers for the proposal among local signers', () {
      final pending = [
        PendingMultisigApprovalEvent.create(
          multisigAddress: 'msig-1',
          proposalId: 1,
          approverId: 'signer-a',
        ),
        PendingMultisigApprovalEvent.create(
          multisigAddress: 'msig-1',
          proposalId: 1,
          approverId: 'other',
        ),
        PendingMultisigApprovalEvent.create(
          multisigAddress: 'msig-1',
          proposalId: 2,
          approverId: 'signer-b',
        ),
      ];

      final ids = pendingApproverIdsForProposal(pending, 'msig-1', 1, const ['signer-a', 'signer-b']);

      expect(ids, {'signer-a'});
    });
  });
}
