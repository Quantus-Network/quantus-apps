// Pins the proposal sheet's action rules: which of Approve, Execute and Cancel
// it offers, in which state, and the note under them. The rules live in
// wallet_core, shared with the desktop app.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

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

/// The indexer lists [listed] among the open proposals or the past ones, as
/// its status says; with none, it lists nothing.
class _FakeMultisigService extends Fake implements MultisigService {
  _FakeMultisigService(this.listed);

  final MultisigProposal? listed;

  @override
  Future<List<MultisigProposal>> getOpenProposals(MultisigAccount msig) async =>
      [?listed].where((proposal) => !proposal.isTerminal).toList();

  @override
  Future<List<MultisigProposal>> getPastProposals(MultisigAccount msig) async =>
      [?listed].where((proposal) => proposal.isTerminal).toList();

  @override
  Future<int> currentBlockNumber() async => _currentBlock;

  @override
  DateTime blockToTime(int targetBlock, int currentBlock) => DateTime.utc(2026);

  @override
  Future<List<int>> fetchProposalCallBytes({required MultisigAccount msig, required int proposalId}) async =>
      _transferBytes;

  @override
  Future<BigInt> estimateApproveFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) async => BigInt.from(1000);

  @override
  Future<BigInt> estimateExecuteFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) async => BigInt.from(1000);

  @override
  Future<BigInt> estimateCancelFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
  }) async => BigInt.from(1000);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

/// Opens the proposal sheet for [proposal] with [accounts] in the wallet,
/// after [pending] has put this device's in-flight actions in place. The
/// indexer lists [proposal] unless [listed] is false.
Future<void> _open(
  WidgetTester tester,
  MultisigProposal proposal, {
  List<Account>? accounts,
  void Function(ProviderContainer container)? pending,
  bool listed = true,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        multisigServiceProvider.overrideWithValue(_FakeMultisigService(listed ? proposal : null)),
        accountsProvider.overrideWith(
          (ref) => AccountsNotifier(AccountsService(), initialAccounts: accounts ?? [_one]),
        ),
        balanceProviderFamily.overrideWith((ref, accountId) => BigInt.from(10).pow(20)),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showMultisigProposalDetailSheet(context, msig: _msig, proposal: proposal),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  pending?.call(_container(tester));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The sheet's button labelled [label].
QuantusButton _button(WidgetTester tester, String label) =>
    tester.widget<QuantusButton>(find.ancestor(of: find.text(label), matching: find.byType(QuantusButton)));

bool _isOffered(WidgetTester tester, String label) {
  final button = _button(tester, label);
  return button.onTap != null && !button.isDisabled;
}

/// Every note the sheet may show under its actions.
List<String> get _allNotes => [
  _l10n.multisigProposalAlreadyCancelledNote,
  _l10n.multisigProposalAlreadyExecutedNote,
  _l10n.multisigProposalCancellingNote,
  _l10n.multisigProposalExecutingNote,
  _l10n.multisigProposalApprovingNote,
  _l10n.multisigProposalExpiredNote,
  _l10n.multisigNoSignerHereNote,
  _l10n.multisigCancelWaitsNote,
  _l10n.multisigProposalAlreadySignedNote,
];

/// The note shown, or null when there is none.
String? _note() {
  final shown = _allNotes.where((note) => find.text(note).evaluate().isNotEmpty).toList();
  expect(shown.length, lessThanOrEqualTo(1), reason: 'at most one note: $shown');
  return shown.firstOrNull;
}

void _addApproval(ProviderContainer container, Account approver) => container
    .read(pendingMultisigApprovalsProvider.notifier)
    .add(
      PendingMultisigApprovalEvent.create(
        multisigAddress: _msig.accountId,
        proposalId: 1,
        approverId: approver.accountId,
        recipient: 'qzbob${'x' * 40}',
        amount: BigInt.one,
      ),
    );

void _addExecution(ProviderContainer container) => container
    .read(pendingMultisigExecutionsProvider.notifier)
    .add(
      PendingMultisigExecutionEvent.create(
        multisigAddress: _msig.accountId,
        proposalId: 1,
        executorId: _one.accountId,
        recipient: 'qzbob${'x' * 40}',
        amount: BigInt.one,
      ),
    );

void _addCancellation(ProviderContainer container) => container
    .read(pendingMultisigCancellationsProvider.notifier)
    .add(
      PendingMultisigCancellationEvent.create(
        multisigAddress: _msig.accountId,
        proposalId: 1,
        proposerId: _one.accountId,
        recipient: 'qzbob${'x' * 40}',
        amount: BigInt.one,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CheckphraseText.resolveOverride = (_) async => 'Stand-Envelope-Topic-Term-Help';

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
  });

  group('over', () {
    testWidgets('an undecodable call: only Done, and no note', (tester) async {
      await _open(tester, _proposal(callRaw: Uint8List.fromList([..._transferBytes, 0x00])));

      expect(find.text(_l10n.multisigDone), findsOneWidget);
      expect(find.text(_l10n.multisigApproveButton), findsNothing);
      expect(find.text(_l10n.multisigExecuteButton), findsNothing);
      expect(find.text(_l10n.multisigCancelProposalButton), findsNothing);
      expect(_note(), isNull);
    });

    for (final (status, note) in [
      (MultisigProposalStatus.executed, () => _l10n.multisigProposalAlreadyExecutedNote),
      (MultisigProposalStatus.cancelled, () => _l10n.multisigProposalAlreadyCancelledNote),
    ]) {
      testWidgets('${status.name}: only Done, with its note, even for the proposer', (tester) async {
        await _open(tester, _proposal(status: status, proposer: _one.accountId));

        expect(find.text(_l10n.multisigDone), findsOneWidget);
        expect(find.text(_l10n.multisigApproveButton), findsNothing);
        expect(find.text(_l10n.multisigExecuteButton), findsNothing);
        expect(find.text(_l10n.multisigCancelProposalButton), findsNothing);
        expect(_note(), note());
      });
    }

    // Once the lists are read again after an execution or cancellation, the
    // open list no longer has it, while the past one may not have it yet, or
    // could not be read.
    for (final (name, proposal) in [
      ('still to approve', _proposal(proposer: _one.accountId)),
      (
        'ready to execute',
        _proposal(
          status: MultisigProposalStatus.approved,
          approvals: [_two.accountId, _three.accountId],
          proposer: _one.accountId,
        ),
      ),
    ]) {
      testWidgets('$name as opened, but in neither the open proposals just read nor the past ones: only Done, '
          'and no note', (tester) async {
        await _open(tester, proposal, listed: false);

        expect(find.text(_l10n.multisigDone), findsOneWidget);
        expect(find.text(_l10n.multisigApproveButton), findsNothing);
        expect(find.text(_l10n.multisigExecuteButton), findsNothing);
        expect(find.text(_l10n.multisigCancelProposalButton), findsNothing);
        expect(_note(), isNull);
      });
    }

    testWidgets('every local signer approved and it is not ready: only Done, with the already-signed note', (
      tester,
    ) async {
      await _open(tester, _proposal(approvals: [_one.accountId]));

      expect(find.text(_l10n.multisigDone), findsOneWidget);
      expect(find.text(_l10n.multisigApproveButton), findsNothing);
      expect(_note(), _l10n.multisigProposalAlreadySignedNote);
    });
  });

  group('approve', () {
    testWidgets('one local signer still to approve: Approve opens its confirmation straight away', (tester) async {
      await _open(tester, _proposal());

      expect(_isOffered(tester, _l10n.multisigApproveButton), isTrue);
      expect(_note(), isNull);

      await tester.tap(find.text(_l10n.multisigApproveButton));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.multisigSignerPickerTitle), findsNothing);
      final confirm = tester.widget<MultisigActionConfirmSheet>(find.byType(MultisigActionConfirmSheet));
      expect(confirm.signer.accountId, _one.accountId);
    });

    testWidgets('two local signers still to approve: Approve asks which first, and that one approves', (tester) async {
      await _open(tester, _proposal(), accounts: [_one, _two]);

      await tester.tap(find.text(_l10n.multisigApproveButton));
      await tester.pumpAndSettle();

      // The picker is the topmost sheet, so its rows are the last of each name.
      expect(find.text(_l10n.multisigSignerPickerTitle), findsOneWidget);
      expect(find.text(_one.name), findsWidgets);
      expect(find.text(_two.name), findsWidgets);

      await tester.tap(find.text(_two.name).last);
      await tester.pumpAndSettle();

      final confirm = tester.widget<MultisigActionConfirmSheet>(find.byType(MultisigActionConfirmSheet));
      expect(confirm.signer.accountId, _two.accountId);
    });

    testWidgets('one local signer approving and another still to: Approve stays, for the other only', (tester) async {
      await _open(tester, _proposal(), accounts: [_one, _two], pending: (c) => _addApproval(c, _one));

      expect(_isOffered(tester, _l10n.multisigApproveButton), isTrue);
      expect(_note(), isNull);

      await tester.tap(find.text(_l10n.multisigApproveButton));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.multisigSignerPickerTitle), findsNothing);
      final confirm = tester.widget<MultisigActionConfirmSheet>(find.byType(MultisigActionConfirmSheet));
      expect(confirm.signer.accountId, _two.accountId);
    });

    testWidgets('the only local signer approving: "Approving…", unavailable, with its note', (tester) async {
      await _open(tester, _proposal(), pending: (c) => _addApproval(c, _one));

      expect(find.text(_l10n.multisigApproveButton), findsNothing);
      expect(_isOffered(tester, _l10n.multisigProposalApprovingLabel), isFalse);
      expect(_note(), _l10n.multisigProposalApprovingNote);
    });

    testWidgets('a cancellation from this device under way: Approve unavailable, with the cancelling note', (
      tester,
    ) async {
      await _open(tester, _proposal(proposer: _one.accountId), pending: _addCancellation);

      expect(_isOffered(tester, _l10n.multisigApproveButton), isFalse);
      expect(_note(), _l10n.multisigProposalCancellingNote);
    });

    testWidgets('expired: Approve unavailable, with the expired note', (tester) async {
      await _open(tester, _proposal(expiryBlock: _currentBlock));

      expect(_isOffered(tester, _l10n.multisigApproveButton), isFalse);
      expect(_note(), _l10n.multisigProposalExpiredNote);
    });

    testWidgets('no signer of it in this wallet: Approve unavailable, with the no-signer note', (tester) async {
      await _open(tester, _proposal(), accounts: [makeAccount(9)]);

      expect(_isOffered(tester, _l10n.multisigApproveButton), isFalse);
      expect(_note(), _l10n.multisigNoSignerHereNote);
    });
  });

  group('execute', () {
    MultisigProposal ready({int expiryBlock = 1000, String? proposer}) => _proposal(
      status: MultisigProposalStatus.approved,
      approvals: [_two.accountId, _three.accountId],
      expiryBlock: expiryBlock,
      proposer: proposer,
    );

    testWidgets('approved: Execute opens its confirmation, signed by this device\'s member', (tester) async {
      await _open(tester, ready());

      expect(find.text(_l10n.multisigApproveButton), findsNothing);
      expect(_isOffered(tester, _l10n.multisigExecuteButton), isTrue);
      expect(_note(), isNull);

      await tester.tap(find.text(_l10n.multisigExecuteButton));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.multisigExecuteConfirmTitle), findsOneWidget);
      expect(
        tester.widget<MultisigActionConfirmSheet>(find.byType(MultisigActionConfirmSheet)).signer.accountId,
        _one.accountId,
      );
    });

    testWidgets('two signers here: Execute asks which first, and that one executes', (tester) async {
      await _open(tester, ready(), accounts: [_one, _two]);

      await tester.tap(find.text(_l10n.multisigExecuteButton));
      await tester.pumpAndSettle();

      // The picker is the topmost sheet, so its rows are the last of each name.
      expect(find.text(_l10n.multisigSignerPickerTitle), findsOneWidget);
      await tester.tap(find.text(_two.name).last);
      await tester.pumpAndSettle();

      expect(find.text(_l10n.multisigExecuteConfirmTitle), findsOneWidget);
      expect(
        tester.widget<MultisigActionConfirmSheet>(find.byType(MultisigActionConfirmSheet)).signer.accountId,
        _two.accountId,
      );
    });

    testWidgets('the member not here but another signer is: Execute offered, by that signer', (tester) async {
      await _open(tester, ready(), accounts: [_two]);

      expect(_isOffered(tester, _l10n.multisigExecuteButton), isTrue);
      await tester.tap(find.text(_l10n.multisigExecuteButton));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.multisigSignerPickerTitle), findsNothing);
      expect(
        tester.widget<MultisigActionConfirmSheet>(find.byType(MultisigActionConfirmSheet)).signer.accountId,
        _two.accountId,
      );
    });

    testWidgets('an approval from this device under way: Execute unavailable, with the approving note', (tester) async {
      await _open(tester, ready(), pending: (c) => _addApproval(c, _one));

      expect(_isOffered(tester, _l10n.multisigExecuteButton), isFalse);
      expect(_note(), _l10n.multisigProposalApprovingNote);
    });

    testWidgets('a cancellation from this device under way: Execute unavailable, with the cancelling note', (
      tester,
    ) async {
      // Only its proposer cancels it.
      await _open(tester, ready(proposer: _one.accountId), pending: _addCancellation);

      expect(_isOffered(tester, _l10n.multisigExecuteButton), isFalse);
      expect(_note(), _l10n.multisigProposalCancellingNote);
    });

    testWidgets('an execution from this device under way: "Executing…", unavailable, with its note', (tester) async {
      await _open(tester, ready(), pending: _addExecution);

      expect(find.text(_l10n.multisigExecuteButton), findsNothing);
      expect(_isOffered(tester, _l10n.multisigProposalExecutingLabel), isFalse);
      expect(_note(), _l10n.multisigProposalExecutingNote);
    });

    testWidgets('expired: Execute unavailable, with the expired note', (tester) async {
      await _open(tester, ready(expiryBlock: _currentBlock));

      expect(_isOffered(tester, _l10n.multisigExecuteButton), isFalse);
      expect(_note(), _l10n.multisigProposalExpiredNote);
    });

    testWidgets('no signer of it in this wallet: Execute unavailable, with the no-signer note', (tester) async {
      await _open(tester, ready(), accounts: [makeAccount(9)]);

      expect(_isOffered(tester, _l10n.multisigExecuteButton), isFalse);
      expect(_note(), _l10n.multisigNoSignerHereNote);
    });
  });

  group('cancel', () {
    testWidgets('the proposer is this device\'s member: Cancel is offered, as danger, and opens its confirmation', (
      tester,
    ) async {
      await _open(tester, _proposal(proposer: _one.accountId));

      final cancel = _button(tester, _l10n.multisigCancelProposalButton);
      expect(cancel.variant, ButtonVariant.danger);
      expect(_isOffered(tester, _l10n.multisigCancelProposalButton), isTrue);

      await tester.tap(find.text(_l10n.multisigCancelProposalButton));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.multisigCancelConfirmTitle), findsOneWidget);
    });

    testWidgets('the proposer is another signer in this wallet: Cancel offered, and its confirmation signs as that '
        'signer', (tester) async {
      await _open(tester, _proposal(proposer: _two.accountId), accounts: [_one, _two]);

      expect(_isOffered(tester, _l10n.multisigCancelProposalButton), isTrue);

      await tester.tap(find.text(_l10n.multisigCancelProposalButton));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.multisigCancelConfirmTitle), findsOneWidget);
      expect(
        tester.widget<MultisigActionConfirmSheet>(find.byType(MultisigActionConfirmSheet)).signer.accountId,
        _two.accountId,
      );
    });

    testWidgets('the proposer is a signer not in this wallet: no Cancel', (tester) async {
      await _open(tester, _proposal(proposer: _two.accountId));

      expect(find.text(_l10n.multisigCancelProposalButton), findsNothing);
    });

    testWidgets('its cancellation under way: "Cancelling…", unavailable', (tester) async {
      await _open(tester, _proposal(proposer: _one.accountId), pending: _addCancellation);

      expect(find.text(_l10n.multisigCancelProposalButton), findsNothing);
      expect(_isOffered(tester, _l10n.multisigProposalCancellingLabel), isFalse);
    });

    testWidgets('an approval from this device under way: Cancel unavailable', (tester) async {
      await _open(
        tester,
        _proposal(proposer: _one.accountId),
        accounts: [_one, _two],
        pending: (c) => _addApproval(c, _two),
      );

      expect(_isOffered(tester, _l10n.multisigCancelProposalButton), isFalse);
    });

    testWidgets('expired: Cancel unavailable', (tester) async {
      await _open(tester, _proposal(proposer: _one.accountId, expiryBlock: _currentBlock));

      expect(_isOffered(tester, _l10n.multisigCancelProposalButton), isFalse);
    });
  });
}
