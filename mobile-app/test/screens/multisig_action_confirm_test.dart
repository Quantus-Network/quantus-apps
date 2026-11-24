// Pins the confirmation of a proposal's approval, execution and cancellation
// as the phone has it today: the proposal's call is read from the chain before
// the fee, Confirm waits for it, failures are said and can be retried. The
// flow moves to wallet_core next, unchanged, so the desktop app can share it.
//
// Asking the person goes through the shared user approval, which the phone
// binds to its biometrics; here it approves unless a test says otherwise.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_approve_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_cancel_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_execute_confirm_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

final _one = makeAccount(1);
final _two = makeAccount(2);

final _msig = MultisigAccount(
  name: 'Msig',
  accountId: 'qzmsig${'x' * 40}',
  signers: [_one.accountId, _two.accountId],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: _one.accountId,
);

final _callBytes = Uint8List.fromList(
  const balances_pallet.Txs()
      .transferAllowDeath(
        dest: multi_address.MultiAddress.values.id(Uint8List.fromList(List.filled(32, 0xBB))),
        value: BigInt.from(1000000000000),
      )
      .encode(),
);

final _fee = BigInt.from(1234);

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
  callRaw: _callBytes,
  expiryBlock: 1000,
  approvals: const [],
  deposit: BigInt.zero,
  status: MultisigProposalStatus.active,
  threshold: _msig.threshold,
  signerCount: _msig.signers.length,
);

/// The chain as the sheet reads it: the proposal's stored call, and fees.
class _FakeMultisigService extends Fake implements MultisigService {
  /// When set, reading the call waits for it; [callError] makes the read fail.
  Completer<List<int>>? holdCall;
  Object? callError;
  int callReads = 0;

  Object? feeError;

  /// Who each estimate was for, and the call bytes it was given.
  final estimates = <(String action, String signer, List<int>? callBytes)>[];

  @override
  Future<List<int>> fetchProposalCallBytes({required MultisigAccount msig, required int proposalId}) async {
    callReads++;
    if (callError case final error?) throw error;
    return holdCall?.future ?? _callBytes;
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

  @override
  Future<List<MultisigProposal>> getOpenProposals(MultisigAccount msig) async => [];

  @override
  Future<int> currentBlockNumber() async => 100;
}

/// Records each action instead of signing and submitting it.
class _FakeSubmission extends Fake implements TransactionSubmissionService {
  Object? error;

  final submitted = <(String action, String signer, BigInt? fee, List<int>? callBytes)>[];

  Future<String> _submit(String action, Account signer, BigInt? fee, List<int>? callBytes) async {
    if (error case final error?) throw error;
    submitted.add((action, signer.accountId, fee, callBytes));
    return '0x${submitted.length}';
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
}

/// The person at the device: approves unless told otherwise, and notes the
/// reason given with each request.
class _FakeApproval implements UserApproval {
  ApprovalResult answer = ApprovalResult.approved;
  final reasons = <String>[];

  @override
  Future<ApprovalAvailability> availability() async => ApprovalAvailability.available;

  @override
  Future<ApprovalResult> approve({required String reason}) async {
    reasons.add(reason);
    return answer;
  }
}

late _FakeApproval _approval;

Future<void> _open(
  WidgetTester tester,
  _FakeMultisigService chain,
  _FakeSubmission submission,
  void Function(BuildContext context) show,
) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        multisigServiceProvider.overrideWithValue(chain),
        transactionSubmissionServiceProvider.overrideWithValue(submission),
        userApprovalProvider.overrideWithValue(_approval),
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: [_one, _two])),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(onPressed: () => show(context), child: const Text('open')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

QuantusButton _button(WidgetTester tester, String label) =>
    tester.widget<QuantusButton>(find.ancestor(of: find.text(label), matching: find.byType(QuantusButton)));

bool _isOffered(WidgetTester tester, String label) {
  final button = _button(tester, label);
  return button.onTap != null && !button.isDisabled;
}

void _approve(BuildContext context, {Account? signer}) =>
    showMultisigApproveConfirmSheet(context, msig: _msig, proposal: _proposal, signer: signer ?? _one);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeMultisigService chain;
  late _FakeSubmission submission;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
    chain = _FakeMultisigService();
    submission = _FakeSubmission();
    _approval = _FakeApproval();
  });

  testWidgets('approve reads the call from the chain first, then prices it with those bytes; Confirm waits for them', (
    tester,
  ) async {
    chain.holdCall = Completer();
    await _open(tester, chain, submission, (context) => _approve(context, signer: _two));

    expect(find.text(_l10n.multisigProposalCallLoading), findsOneWidget);
    expect(_isOffered(tester, _l10n.multisigApproveConfirmYes), isFalse);
    expect(chain.estimates, isEmpty, reason: 'the fee waits for the call');

    chain.holdCall!.complete(_callBytes);
    await tester.pumpAndSettle();

    expect(chain.callReads, 1);
    expect(chain.estimates, [('approve', _two.accountId, _callBytes)]);
    expect(find.text(_l10n.multisigProposalCallLoading), findsNothing);
    expect(_isOffered(tester, _l10n.multisigApproveConfirmYes), isTrue);
  });

  testWidgets('when the call cannot be read, it says so, asks no fee, and Confirm stays unavailable', (tester) async {
    chain.callError = StateError('not on chain');
    await _open(tester, chain, submission, (context) => _approve(context, signer: _two));

    expect(find.text(_l10n.multisigProposalCallUnavailable), findsOneWidget);
    expect(chain.estimates, isEmpty);
    expect(_isOffered(tester, _l10n.multisigApproveConfirmYes), isFalse);
  });

  testWidgets('when the fee cannot be estimated, it says so and Confirm is still offered', (tester) async {
    chain.feeError = StateError('no fee');
    await _open(tester, chain, submission, (context) => _approve(context, signer: _two));

    expect(find.text(_l10n.multisigFeeEstimateUnavailable), findsOneWidget);
    expect(_isOffered(tester, _l10n.multisigApproveConfirmYes), isTrue);
  });

  testWidgets('confirming approves as the chosen signer with the chain\'s bytes, then closes', (tester) async {
    await _open(tester, chain, submission, (context) => _approve(context, signer: _two));

    await tester.tap(find.text(_l10n.multisigApproveConfirmYes));
    await tester.pumpAndSettle();

    expect(submission.submitted, [('approve', _two.accountId, null, _callBytes)]);
    expect(find.byType(MultisigActionConfirmSheet), findsNothing);
  });

  testWidgets('with no signer chosen, it approves as this device\'s member', (tester) async {
    await _open(tester, chain, submission, (context) => _approve(context));

    expect(chain.estimates.single.$2, _one.accountId);

    await tester.tap(find.text(_l10n.multisigApproveConfirmYes));
    await tester.pumpAndSettle();

    expect(submission.submitted.single.$2, _one.accountId);
  });

  testWidgets('a failed submission says so, stays open, and can be tried again', (tester) async {
    submission.error = StateError('rejected');
    await _open(tester, chain, submission, (context) => _approve(context, signer: _two));

    await tester.tap(find.text(_l10n.multisigApproveConfirmYes));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.multisigApproveFailed), findsOneWidget);
    expect(find.byType(MultisigActionConfirmSheet), findsOneWidget);
    expect(_isOffered(tester, _l10n.multisigApproveConfirmYes), isTrue);

    submission.error = null;
    await tester.tap(find.text(_l10n.multisigApproveConfirmYes));
    await tester.pumpAndSettle();

    expect(submission.submitted, [('approve', _two.accountId, null, _callBytes)]);
    expect(find.byType(MultisigActionConfirmSheet), findsNothing);
  });

  testWidgets('a declined approval says approval is required, submits nothing, and stays open', (tester) async {
    _approval.answer = ApprovalResult.declined;
    await _open(tester, chain, submission, (context) => _approve(context, signer: _two));

    await tester.tap(find.text(_l10n.multisigApproveConfirmYes));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.multisigAuthRequired), findsOneWidget);
    expect(submission.submitted, isEmpty);
    expect(find.byType(MultisigActionConfirmSheet), findsOneWidget);
    expect(_isOffered(tester, _l10n.multisigApproveConfirmYes), isTrue);
  });

  for (final (name, show, confirmLabel, reason) in [
    ('approve', _approve, () => _l10n.multisigApproveConfirmYes, () => _l10n.multisigApproveAuthReason),
    (
      'execute',
      (BuildContext context) =>
          showMultisigExecuteConfirmSheet(context, msig: _msig, proposal: _proposal, signer: _one),
      () => _l10n.multisigExecuteConfirmYes,
      () => _l10n.multisigExecuteAuthReason,
    ),
    (
      'cancel',
      (BuildContext context) => showMultisigCancelConfirmSheet(context, msig: _msig, proposal: _proposal, signer: _one),
      () => _l10n.multisigCancelConfirmYes,
      () => _l10n.multisigCancelAuthReason,
    ),
  ]) {
    testWidgets('$name asks for approval with its own reason', (tester) async {
      await _open(tester, chain, submission, show);

      await tester.tap(find.text(confirmLabel()));
      await tester.pumpAndSettle();

      expect(_approval.reasons, [reason()]);
    });
  }

  testWidgets('execute reads the call, prices it, and executes as this device\'s member with that fee', (tester) async {
    await _open(
      tester,
      chain,
      submission,
      (context) => showMultisigExecuteConfirmSheet(context, msig: _msig, proposal: _proposal, signer: _one),
    );

    expect(chain.callReads, 1);
    expect(chain.estimates, [('execute', _one.accountId, _callBytes)]);

    await tester.tap(find.text(_l10n.multisigExecuteConfirmYes));
    await tester.pumpAndSettle();

    expect(submission.submitted, [('execute', _one.accountId, _fee, _callBytes)]);
    expect(find.byType(MultisigActionConfirmSheet), findsNothing);
  });

  testWidgets('cancel is confirmed in danger, priced and cancelled as this device\'s member with that fee', (
    tester,
  ) async {
    await _open(
      tester,
      chain,
      submission,
      (context) => showMultisigCancelConfirmSheet(context, msig: _msig, proposal: _proposal, signer: _one),
    );

    expect(_button(tester, _l10n.multisigCancelConfirmYes).variant, ButtonVariant.danger);
    expect(chain.estimates, [('cancel', _one.accountId, null)]);

    await tester.tap(find.text(_l10n.multisigCancelConfirmYes));
    await tester.pumpAndSettle();

    expect(submission.submitted, [('cancel', _one.accountId, _fee, null)]);
    expect(find.byType(MultisigActionConfirmSheet), findsNothing);
  });
}
