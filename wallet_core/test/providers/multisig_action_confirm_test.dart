import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../fakes.dart';

final _one = makeAccount(1);
final _two = makeAccount(2);
final _keystone = makeAccount(3, accountType: AccountType.keystone);

/// Two signers needed of three; this device's member is the first.
final _msig = MultisigAccount(
  name: 'Msig',
  accountId: 'qzmsig${'x' * 40}',
  signers: [_one.accountId, _two.accountId, _keystone.accountId],
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

final _proposal = MultisigProposal(
  entityId: 'p1',
  id: 1,
  multisigAddress: _msig.accountId,
  proposer: _one.accountId,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  pallet: 'Balances',
  call: 'transfer_allow_death',
  recipient: 'qzbob${'x' * 40}',
  amount: BigInt.from(1000000000000),
  callRaw: _transferBytes,
  expiryBlock: 1000,
  approvals: const [],
  deposit: BigInt.zero,
  status: MultisigProposalStatus.active,
  threshold: _msig.threshold,
  signerCount: _msig.signers.length,
);

final _fee = BigInt.from(1000);

/// The chain: it holds the proposal's call bytes until the test lets them go
/// when [holdCall] is set, and fails reads or estimates when told to.
class _Chain extends Fake implements MultisigService {
  Completer<void>? holdCall;
  Object? callError;
  Object? feeError;
  List<int> callBytes = _transferBytes;

  /// The fee estimates asked for, in order: the action and the bytes given.
  final estimates = <(String action, String signer, List<int>? callBytes)>[];

  @override
  Future<List<int>> fetchProposalCallBytes({required MultisigAccount msig, required int proposalId}) async {
    await holdCall?.future;
    if (callError case final error?) throw error;
    return callBytes;
  }

  Future<BigInt> _estimate(String action, Account signer, List<int>? callBytes) async {
    estimates.add((action, signer.accountId, callBytes));
    if (feeError case final error?) throw error;
    return _fee;
  }

  @override
  Future<BigInt> estimateApproveFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) => _estimate('approve', signer, callBytes);

  @override
  Future<BigInt> estimateExecuteFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) => _estimate('execute', signer, callBytes);

  @override
  Future<BigInt> estimateCancelFee({required MultisigAccount msig, required Account signer, required int proposalId}) =>
      _estimate('cancel', signer, null);
}

class _Unsigned extends Fake implements UnsignedTransactionData {}

/// Records each action instead of signing and submitting it.
class _Submission extends Fake implements TransactionSubmissionService {
  Object? error;

  final submitted = <(String action, String signer, BigInt? fee, List<int>? callBytes)>[];

  Future<String> _submit(String action, Account signer, BigInt? fee, List<int>? callBytes) async {
    if (error case final error?) throw error;
    submitted.add((action, signer.accountId, fee, callBytes));
    return '0x$action';
  }

  @override
  Future<String> approveProposal({
    required MultisigAccount msig,
    required Account signer,
    required MultisigProposal proposal,
    List<int>? callBytes,
  }) => _submit('approve', signer, null, callBytes);

  @override
  Future<String> executeProposal({
    required MultisigAccount msig,
    required Account signer,
    required MultisigProposal proposal,
    List<int>? callBytes,
    BigInt? fee,
  }) => _submit('execute', signer, fee, callBytes);

  @override
  Future<String> cancelProposal({
    required MultisigAccount msig,
    required Account proposer,
    required MultisigProposal proposal,
    BigInt? fee,
  }) => _submit('cancel', proposer, fee, null);

  @override
  Future<String> approveProposalWithExternalSignature({
    required MultisigAccount msig,
    required Account signer,
    required MultisigProposal proposal,
    required UnsignedTransactionData unsignedData,
    required Uint8List signatureWithPublicKey,
  }) => _submit('approve signed', signer, null, null);
}

typedef _Confirm = ({
  WidgetRef ref,
  MultisigActionConfirmState Function() state,
  MultisigActionConfirmController controller,
});

void main() {
  late WalletTestBed bed;
  late _Chain chain;
  late _Submission submission;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bed = WalletTestBed();
    chain = _Chain();
    submission = _Submission();
  });

  /// Opens the confirmation of [kind], kept open by a widget watching it.
  Future<_Confirm> open(WidgetTester tester, MultisigActionKind kind, {Account? signer}) async {
    final request = MultisigActionRequest(kind: kind, msig: _msig, proposal: _proposal, signer: signer);
    final provider = multisigActionConfirmProvider(request);
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...bed.overrides,
          multisigServiceProvider.overrideWithValue(chain),
          transactionSubmissionServiceProvider.overrideWithValue(submission),
          accountsProvider.overrideWith(
            (ref) => AccountsNotifier(bed.accounts, initialAccounts: [_one, _two, _keystone]),
          ),
        ],
        child: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            widgetRef.watch(provider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    return (ref: ref, state: () => ref.read(provider), controller: ref.read(provider.notifier));
  }

  group('before Confirm', () {
    testWidgets('the call is read before the fee, and Confirm waits until it decodes', (tester) async {
      chain.holdCall = Completer<void>();
      final confirm = await open(tester, MultisigActionKind.approve);

      expect(confirm.state().loadingCall, isTrue);
      expect(confirm.state().canConfirm, isFalse);
      expect(chain.estimates, isEmpty);

      chain.holdCall!.complete();
      await tester.pump();
      await tester.pump();

      expect(confirm.state().loadingCall, isFalse);
      expect(confirm.state().decodedCall, isNotNull);
      expect(chain.estimates, [('approve', _one.accountId, _transferBytes)]);
      expect(confirm.state().fee, _fee);
      expect(confirm.state().canConfirm, isTrue);
    });

    for (final (why, unreadable) in [
      ('cannot be read', (_Chain chain) => chain.callError = StateError('no such proposal')),
      ('does not decode', (_Chain chain) => chain.callBytes = [..._transferBytes, 0x00]),
    ]) {
      testWidgets('a call that $why asks for no fee and cannot be confirmed', (tester) async {
        unreadable(chain);
        final confirm = await open(tester, MultisigActionKind.approve);
        await tester.pump();

        expect(confirm.state().callUnavailable, isTrue);
        expect(confirm.state().decodedCall, isNull);
        expect(confirm.state().loadingFee, isFalse);
        expect(chain.estimates, isEmpty);
        expect(confirm.state().canConfirm, isFalse);
      });
    }

    testWidgets('a fee that cannot be estimated is said, and Confirm is still offered', (tester) async {
      chain.feeError = StateError('the node is down');
      final confirm = await open(tester, MultisigActionKind.approve);
      await tester.pump();

      expect(confirm.state().feeUnavailable, isTrue);
      expect(confirm.state().fee, isNull);
      expect(confirm.state().canConfirm, isTrue);
    });
  });

  group('approval', () {
    for (final (kind, reason) in [
      (MultisigActionKind.approve, (WidgetRef ref) => ref.read(l10nProvider).multisigApproveAuthReason),
      (MultisigActionKind.execute, (WidgetRef ref) => ref.read(l10nProvider).multisigExecuteAuthReason),
      (MultisigActionKind.cancel, (WidgetRef ref) => ref.read(l10nProvider).multisigCancelAuthReason),
    ]) {
      testWidgets('${kind.name} asks with its own reason', (tester) async {
        final confirm = await open(tester, kind);
        await tester.pump();

        await confirm.controller.confirm();

        expect(bed.userApproval.reasons, [reason(confirm.ref)]);
      });
    }

    for (final answer in [ApprovalResult.declined, ApprovalResult.notSetUp]) {
      testWidgets('${answer.name}: nothing is submitted, approval is required, and Confirm is offered again', (
        tester,
      ) async {
        bed.userApproval.answer = () async => answer;
        final confirm = await open(tester, MultisigActionKind.approve);
        await tester.pump();

        final outcome = await confirm.controller.confirm();

        expect(outcome, isA<MultisigActionFailed>());
        expect((outcome as MultisigActionFailed).error, MultisigActionError.approvalRequired);
        expect(confirm.state().error, MultisigActionError.approvalRequired);
        expect(submission.submitted, isEmpty);
        expect(confirm.state().canConfirm, isTrue);
      });
    }
  });

  group('submitting', () {
    testWidgets('approve submits as the chosen signer with the chain\'s call, and returns the hash', (tester) async {
      final confirm = await open(tester, MultisigActionKind.approve, signer: _two);
      await tester.pump();

      final outcome = await confirm.controller.confirm();

      expect((outcome as MultisigActionSubmitted).hash, '0xapprove');
      expect(submission.submitted, [('approve', _two.accountId, null, _transferBytes)]);
    });

    testWidgets('approve with no signer chosen submits as this device\'s member', (tester) async {
      final confirm = await open(tester, MultisigActionKind.approve);
      await tester.pump();

      await confirm.controller.confirm();

      expect(submission.submitted, [('approve', _one.accountId, null, _transferBytes)]);
    });

    testWidgets('execute submits as this device\'s member with the call and the fee, and returns the hash', (
      tester,
    ) async {
      final confirm = await open(tester, MultisigActionKind.execute);
      await tester.pump();

      final outcome = await confirm.controller.confirm();

      expect(chain.estimates, [('execute', _one.accountId, _transferBytes)]);
      expect((outcome as MultisigActionSubmitted).hash, '0xexecute');
      expect(submission.submitted, [('execute', _one.accountId, _fee, _transferBytes)]);
    });

    testWidgets('cancel submits as this device\'s member with the fee, and returns the hash', (tester) async {
      final confirm = await open(tester, MultisigActionKind.cancel);
      await tester.pump();

      final outcome = await confirm.controller.confirm();

      expect(chain.estimates, [('cancel', _one.accountId, null)]);
      expect((outcome as MultisigActionSubmitted).hash, '0xcancel');
      expect(submission.submitted, [('cancel', _one.accountId, _fee, null)]);
    });

    testWidgets('a failed submission says so, and Confirm is offered again', (tester) async {
      submission.error = StateError('rejected');
      final confirm = await open(tester, MultisigActionKind.approve);
      await tester.pump();

      final outcome = await confirm.controller.confirm();

      expect((outcome as MultisigActionFailed).error, MultisigActionError.submitFailed);
      expect(confirm.state().error, MultisigActionError.submitFailed);
      expect(confirm.state().canConfirm, isTrue);

      submission.error = null;
      final retried = await confirm.controller.confirm();

      expect(retried, isA<MultisigActionSubmitted>());
      expect(confirm.state().error, isNull);
    });

    testWidgets('a Keystone signer is not asked for approval: its signing session submits and returns the hash', (
      tester,
    ) async {
      final confirm = await open(tester, MultisigActionKind.approve, signer: _keystone);
      await tester.pump();

      final outcome = await confirm.controller.confirm();

      expect(bed.userApproval.reasons, isEmpty);
      expect(submission.submitted, isEmpty);
      final session = (outcome as MultisigActionNeedsHardwareSignature).session(primaryDetail: 'Send 1 QTC');
      expect(session.account.accountId, _keystone.accountId);
      expect(session.primaryDetail, 'Send 1 QTC');

      final hash = await session.submitSigned(
        confirm.ref,
        unsignedData: _Unsigned(),
        signatureWithPublicKey: Uint8List(1),
      );

      expect(hash, '0xapprove signed');
      expect(submission.submitted, [('approve signed', _keystone.accountId, null, null)]);
    });
  });
}
