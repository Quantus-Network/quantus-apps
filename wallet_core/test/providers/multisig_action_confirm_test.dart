import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/utils/polling_refresh_scope.dart';
import 'package:wallet_core/providers/shown_balances_provider.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
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

  /// How many times the proposal's call was read.
  int callReads = 0;

  /// The fee estimates asked for, in order: the action and the bytes given.
  final estimates = <(String action, String signer, List<int>? callBytes)>[];

  @override
  Future<List<int>> fetchProposalCallBytes({required MultisigAccount msig, required int proposalId}) async {
    callReads++;
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
    BigInt? fee,
  }) => _submit('approve', signer, fee, callBytes);

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
    BigInt? fee,
  }) => _submit('approve signed', signer, fee, null);

  @override
  Future<String> executeProposalWithExternalSignature({
    required MultisigAccount msig,
    required Account signer,
    required MultisigProposal proposal,
    required UnsignedTransactionData unsignedData,
    required Uint8List signatureWithPublicKey,
    BigInt? fee,
  }) => _submit('execute signed', signer, fee, null);

  @override
  Future<String> cancelProposalWithExternalSignature({
    required MultisigAccount msig,
    required Account proposer,
    required MultisigProposal proposal,
    required UnsignedTransactionData unsignedData,
    required Uint8List signatureWithPublicKey,
    BigInt? fee,
  }) => _submit('cancel signed', proposer, fee, null);
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

  /// What each account holds; one not here holds plenty. While [balanceHeld]
  /// is set, no balance is known.
  late Map<String, BigInt> holds;
  Completer<BigInt>? balanceHeld;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bed = WalletTestBed();
    chain = _Chain();
    submission = _Submission();
    holds = {};
    balanceHeld = null;
  });

  List<Override> overrides() => [
    ...bed.overrides,
    multisigServiceProvider.overrideWithValue(chain),
    transactionSubmissionServiceProvider.overrideWithValue(submission),
    accountsProvider.overrideWith((ref) => AccountsNotifier(bed.accounts, initialAccounts: [_one, _two, _keystone])),
    balanceProviderFamily.overrideWith(
      (ref, accountId) => balanceHeld?.future ?? holds[accountId] ?? _fee * BigInt.from(1000),
    ),
  ];

  /// Opens the confirmation of [kind] by this device's member as a review that
  /// offers a choice of signer does: the confirmation of the signer chosen is
  /// watched in place of the one before. [firstSeen] keeps what each signer's
  /// confirmation showed when it opened.
  Future<({ValueNotifier<Account> signer, Map<String, MultisigActionConfirmState> firstSeen})> openChoosing(
    WidgetTester tester,
    MultisigActionKind kind,
  ) async {
    final signer = ValueNotifier<Account>(_one);
    addTearDown(signer.dispose);
    final firstSeen = <String, MultisigActionConfirmState>{};
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: ValueListenableBuilder<Account>(
          valueListenable: signer,
          builder: (context, chosen, _) => Consumer(
            builder: (context, ref, _) {
              final request = MultisigActionRequest(kind: kind, msig: _msig, proposal: _proposal, signer: chosen);
              firstSeen.putIfAbsent(chosen.accountId, () => ref.watch(multisigActionConfirmProvider(request)));
              ref.watch(multisigActionConfirmProvider(request));
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return (signer: signer, firstSeen: firstSeen);
  }

  /// Opens the confirmation of [kind] by [signer], this device's member unless
  /// given, kept open by a widget watching it.
  Future<_Confirm> open(WidgetTester tester, MultisigActionKind kind, {Account? signer}) async {
    signer ??= _one;
    final request = MultisigActionRequest(kind: kind, msig: _msig, proposal: _proposal, signer: signer);
    final provider = multisigActionConfirmProvider(request);
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
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

  group('the call, read once for the proposal', () {
    for (final kind in [MultisigActionKind.approve, MultisigActionKind.execute]) {
      testWidgets('${kind.name}: another signer reuses the call read, and opens with it', (tester) async {
        final choosing = await openChoosing(tester, kind);
        await tester.pump();
        expect(chain.callReads, 1);

        choosing.signer.value = _two;
        await tester.pump();
        await tester.pump();

        expect(chain.callReads, 1, reason: 'the call is the one already read');
        final opened = choosing.firstSeen[_two.accountId]!;
        expect(opened.loadingCall, isFalse);
        expect(opened.callBytes, _transferBytes);
        expect(opened.decodedCall, isNotNull);
        expect(chain.estimates.map((estimate) => estimate.$2), [_one.accountId, _two.accountId]);
      });
    }

    testWidgets('a call that could not be read is read again by the next signer, never kept', (tester) async {
      chain.callError = Exception('the node is down');
      final choosing = await openChoosing(tester, MultisigActionKind.approve);
      await tester.pump();
      expect(choosing.firstSeen[_one.accountId]!.loadingCall, isTrue);
      expect(chain.callReads, 1);

      chain.callError = null;
      choosing.signer.value = _two;
      await tester.pump();
      await tester.pump();

      expect(chain.callReads, 2);
      expect(choosing.firstSeen[_two.accountId]!.loadingCall, isTrue);
      expect(chain.estimates.map((estimate) => estimate.$2), [_two.accountId]);
    });
  });

  group('what the signer holds', () {
    testWidgets('less than the fee: said, Confirm unavailable, and a confirm asks nothing and sends nothing', (
      tester,
    ) async {
      holds[_two.accountId] = _fee - BigInt.one;
      final confirm = await open(tester, MultisigActionKind.execute, signer: _two);
      await tester.pump();

      expect(confirm.state().cannotPayFee, isTrue);
      expect(confirm.state().canConfirm, isFalse);

      final outcome = await confirm.controller.confirm();

      expect((outcome as MultisigActionFailed).error, MultisigActionError.feePayerInsufficient);
      expect(bed.userApproval.reasons, isEmpty);
      expect(submission.submitted, isEmpty);
    });

    testWidgets('exactly the fee is enough', (tester) async {
      holds[_one.accountId] = _fee;
      final confirm = await open(tester, MultisigActionKind.cancel);
      await tester.pump();

      expect(confirm.state().cannotPayFee, isFalse);
      expect(await confirm.controller.confirm(), isA<MultisigActionSubmitted>());
    });

    testWidgets('a balance not known yet is no objection', (tester) async {
      balanceHeld = Completer<BigInt>();
      final confirm = await open(tester, MultisigActionKind.approve);
      await tester.pump();

      expect(confirm.state().fee, _fee);
      expect(confirm.state().cannotPayFee, isFalse);
      expect(confirm.state().canConfirm, isTrue);
    });

    testWidgets('falling below the fee while approval is asked sends nothing, and says so', (tester) async {
      holds[_one.accountId] = _fee;
      final confirm = await open(tester, MultisigActionKind.approve);
      await tester.pump();
      bed.userApproval.answer = () async {
        holds[_one.accountId] = _fee - BigInt.one;
        confirm.ref.invalidate(balanceProviderFamily(_one.accountId));
        return ApprovalResult.approved;
      };

      final outcome = await confirm.controller.confirm();

      expect((outcome as MultisigActionFailed).error, MultisigActionError.feePayerInsufficient);
      expect(bed.userApproval.reasons, hasLength(1));
      expect(submission.submitted, isEmpty);
    });

    testWidgets('a Keystone signer that cannot pay gets no signing session', (tester) async {
      holds[_keystone.accountId] = BigInt.zero;
      final confirm = await open(tester, MultisigActionKind.approve, signer: _keystone);
      await tester.pump();

      final outcome = await confirm.controller.confirm();

      expect((outcome as MultisigActionFailed).error, MultisigActionError.feePayerInsufficient);
    });

    testWidgets('falling below the fee while the Keystone signs sends nothing, and says why', (tester) async {
      holds[_keystone.accountId] = _fee;
      final confirm = await open(tester, MultisigActionKind.approve, signer: _keystone);
      await tester.pump();
      final session = ((await confirm.controller.confirm()) as MultisigActionNeedsHardwareSignature).session(
        primaryDetail: 'Send 1 QTC',
      );

      holds[_keystone.accountId] = _fee - BigInt.one;
      confirm.ref.invalidate(balanceProviderFamily(_keystone.accountId));

      await expectLater(
        session.submitSigned(confirm.ref, unsignedData: _Unsigned(), signatureWithPublicKey: Uint8List(1)),
        throwsA(isA<SignerCannotPayFee>()),
      );
      expect(submission.submitted, isEmpty);
    });
  });

  group('a signer funded after its balance was read', () {
    final refProvider = Provider<Ref>((ref) => ref);

    /// The wallet with the multisig selected, the signer's balance already
    /// read once, at nothing.
    Future<ProviderContainer> walletWithStaleSigner(WidgetTester tester) async {
      bed.settings.activeAccount = MultisigDisplayAccount(_msig);
      final container = ProviderContainer(
        overrides: [
          ...bed.overrides,
          multisigServiceProvider.overrideWithValue(chain),
          transactionSubmissionServiceProvider.overrideWithValue(submission),
          accountsProvider.overrideWith(
            (ref) => AccountsNotifier(bed.accounts, initialAccounts: [_one, _two, _keystone]),
          ),
          balanceProviderFamily.overrideWith((ref, accountId) => holds[accountId] ?? _fee * BigInt.from(1000)),
        ],
      );
      holds[_two.accountId] = BigInt.zero;
      await container.read(balanceProviderFamily(_two.accountId).future);
      holds[_two.accountId] = _fee * BigInt.from(1000);
      return container;
    }

    MultisigActionRequest by(Account signer) =>
        MultisigActionRequest(kind: MultisigActionKind.approve, msig: _msig, proposal: _proposal, signer: signer);

    testWidgets('opening the confirmation reads it again: it can confirm', (tester) async {
      final container = await walletWithStaleSigner(tester);

      container.listen(multisigActionConfirmProvider(by(_two)), (_, _) {});
      await tester.pump();
      await tester.pump();

      expect(container.read(multisigActionConfirmProvider(by(_two))).cannotPayFee, isFalse);
      expect(container.read(multisigActionConfirmProvider(by(_two))).canConfirm, isTrue);
      container.dispose();
      await tester.pump(const Duration(minutes: 1));
    });

    testWidgets('with the multisig selected, its signers here are among the balances a refresh reads again', (
      tester,
    ) async {
      final container = await walletWithStaleSigner(tester);
      container.listen(activeAccountProvider, (_, _) {});
      await tester.pump();
      expect(container.read(activeAccountProvider).value?.account.accountId, _msig.accountId);

      expect(container.read(shownBalanceAccountIdsProvider), containsAll([_one.accountId, _two.accountId]));
      container.listen(balanceProviderFamily(_two.accountId), (_, _) {});
      invalidateShownAccountBalances(container.read(refProvider));
      await tester.pump();

      expect(container.read(balanceProviderFamily(_two.accountId)).value, _fee * BigInt.from(1000));
      container.dispose();
      await tester.pump(const Duration(minutes: 1));
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

    testWidgets('an approval prompt that fails: nothing is submitted, it says the action failed, and Confirm is '
        'offered again', (tester) async {
      bed.userApproval.answer = () async => throw StateError('the prompt could not be shown');
      final confirm = await open(tester, MultisigActionKind.approve);
      await tester.pump();

      final outcome = await confirm.controller.confirm();

      expect((outcome as MultisigActionFailed).error, MultisigActionError.submitFailed);
      expect(confirm.state().submitting, isFalse);
      expect(confirm.state().canConfirm, isTrue);
      expect(submission.submitted, isEmpty);
    });

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
    testWidgets('approve submits as the chosen signer with the chain\'s call and the fee, and returns the hash', (
      tester,
    ) async {
      final confirm = await open(tester, MultisigActionKind.approve, signer: _two);
      await tester.pump();

      final outcome = await confirm.controller.confirm();

      expect((outcome as MultisigActionSubmitted).hash, '0xapprove');
      expect(submission.submitted, [('approve', _two.accountId, _fee, _transferBytes)]);
    });

    testWidgets('execute submits as the signer it is given with the call and the fee, and returns the hash', (
      tester,
    ) async {
      final confirm = await open(tester, MultisigActionKind.execute);
      await tester.pump();

      final outcome = await confirm.controller.confirm();

      expect(chain.estimates, [('execute', _one.accountId, _transferBytes)]);
      expect((outcome as MultisigActionSubmitted).hash, '0xexecute');
      expect(submission.submitted, [('execute', _one.accountId, _fee, _transferBytes)]);
    });

    testWidgets('execute is priced and submitted as the chosen signer, not the member', (tester) async {
      final confirm = await open(tester, MultisigActionKind.execute, signer: _two);
      await tester.pump();

      await confirm.controller.confirm();

      expect(chain.estimates, [('execute', _two.accountId, _transferBytes)]);
      expect(submission.submitted, [('execute', _two.accountId, _fee, _transferBytes)]);
    });

    testWidgets('cancel submits as the signer it is given with the fee, and returns the hash', (tester) async {
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
      expect(submission.submitted, [('approve signed', _keystone.accountId, _fee, null)]);
    });
  });

  group('a wallet reset', () {
    for (final kind in MultisigActionKind.values) {
      testWidgets('before a Keystone signature for ${kind.name} comes back: nothing sent, no row left', (tester) async {
        final confirm = await open(tester, kind, signer: _keystone);
        await tester.pump();
        final session = ((await confirm.controller.confirm()) as MultisigActionNeedsHardwareSignature).session(
          primaryDetail: 'Send 1 QTC',
        );

        await confirm.ref.read(logoutServiceProvider).logout();

        await expectLater(
          session.submitSigned(confirm.ref, unsignedData: _Unsigned(), signatureWithPublicKey: Uint8List(1)),
          throwsStateError,
        );
        expect(submission.submitted, isEmpty);
        expect(confirm.ref.read(pendingMultisigApprovalsProvider), isEmpty);
        expect(confirm.ref.read(pendingMultisigExecutionsProvider), isEmpty);
        expect(confirm.ref.read(pendingMultisigCancellationsProvider), isEmpty);
      });
    }
  });
}
