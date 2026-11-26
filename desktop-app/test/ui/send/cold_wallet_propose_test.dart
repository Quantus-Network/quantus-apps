import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/qr_scan_source.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/keystone/keystone_signing_view.dart';
import 'package:quantus_desktop_wallet/ui/send/send_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/utils/send_strategies.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/send/multisig_propose_strategy.dart';
import 'package:wallet_core/send/send_fee_notifier.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

/// A multisig of three signers that needs two, of which Vault, an account of
/// this wallet whose key is on a cold wallet, is one.
final _coldTeam = MultisigAccount(
  name: 'Cold Team',
  accountId: 'qzColdTeam',
  signers: const ['qzVault', 'qzOther', 'qzThird'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzVault',
);

/// [tokens] in the chain's smallest unit.
BigInt _qtc(num tokens) => BigInt.from((tokens * 10000).round()) * oneToken ~/ BigInt.from(10000);

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder _toolbarPropose() =>
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, 'Propose'));

Finder _editable(Key field) => find.descendant(of: find.byKey(field), matching: find.byType(EditableText));

bool _canPress(WidgetTester tester, Key key) {
  final button = tester.widget<SheetButton>(find.byKey(key));
  return !button.isDisabled && !button.isLoading;
}

class _Harness {
  _Harness(this.chain, this.approval, this.camera, this.opened);

  final FakeSendChain chain;
  final FakeUserApproval approval;
  final FakeScanSource camera;
  final List<Uri> opened;
}

/// Opens the wallet on Cold Team, without pressing anything.
Future<_Harness> _pumpColdTeam(WidgetTester tester, {FakeUserApproval? approval}) async {
  final chain = FakeSendChain();
  approval ??= FakeUserApproval();
  final camera = FakeScanSource();
  final opened = <Uri>[];
  await pumpShell(
    tester,
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, vaultAccount],
        settings: FakeSettingsService(
          activeAccount: MultisigDisplayAccount(_coldTeam),
          multisigs: [_coldTeam],
          openWallets: const {0, 1},
        ),
        balances: {'qzMain': oneToken, 'qzVault': _qtc(1250), 'qzColdTeam': _qtc(4800)},
        approval: approval,
        chain: chain,
      ),
      animatedQrScanSourceFactoryProvider.overrideWithValue(() => camera),
      openExternalUrlProvider.overrideWithValue((url) async => opened.add(url)),
    ],
  );
  return _Harness(chain, approval, camera, opened);
}

/// Opens the wallet on Cold Team and presses Propose.
Future<_Harness> _openPropose(WidgetTester tester, {FakeUserApproval? approval}) async {
  final harness = await _pumpColdTeam(tester, approval: approval);
  await tester.tap(_toolbarPropose());
  await tester.pumpAndSettle();
  return harness;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Fills the form with 250 to qzPayee and waits for its cost.
Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(_editable(SendSheet.addressFieldKey), 'qzPayee');
  await tester.pump();
  await tester.enterText(_editable(SendSheet.amountFieldKey), '250');
  await tester.pump();
  await tester.pump(SendFeeNotifier.debounce);
  await tester.pumpAndSettle();
}

/// From the form, Review then Propose: the request QR code is shown.
Future<void> _toShow(WidgetTester tester) async {
  await _fill(tester);
  await _tap(tester, SendSheet.reviewKey);
  await _tap(tester, SendSheet.sendKey);
}

/// On to the camera, which reads the whole signature.
Future<void> _signOnColdWallet(WidgetTester tester, FakeScanSource camera) async {
  await _tap(tester, KeystoneSigningView.continueKey);
  for (final frame in fakeSignatureFrames(3)) {
    camera.read(frame);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// The wallet learns the proposal broadcast as the fake chain's `0xhash` was
/// created.
Future<void> _created(WidgetTester tester) async {
  ProviderScope.containerOf(
    tester.element(find.byType(ShellSheetView)),
  ).read(multisigProposalConfirmationsProvider.notifier).settle('0xhash', SendConfirmation.confirmed);
  await tester.pumpAndSettle();
}

void main() {
  group('opening Propose', () {
    test('a multisig whose member here is a cold wallet proposes, the cold wallet\'s account signing and paying', () {
      final strategy = sendStrategyFor(MultisigDisplayAccount(_coldTeam), accounts: const [mainAccount, vaultAccount]);

      expect(strategy, isA<MultisigProposeStrategy>());
      expect(sendSigner(strategy!, const [mainAccount, vaultAccount]), vaultAccount);
    });

    testOnMac('Propose can be used on it, in the toolbar and with ⌘P', (tester) async {
      await _pumpColdTeam(tester);
      expect(tester.widget<ToolbarAction>(_toolbarPropose()).onPressed, isNotNull);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      expect(find.byType(SendSheet), findsOneWidget);
    });

    testOnMac('Review is available where this Mac cannot approve, and the form says nothing of approval', (
      tester,
    ) async {
      await _openPropose(tester, approval: FakeUserApproval()..availabilityAnswer = ApprovalAvailability.notSetUp);

      await _fill(tester);

      expect(_inSheet(find.text('Set up a login password for this Mac to use this.')), findsNothing);
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
    });

    testOnMac('Propose on the review opens the signing steps in the sheet, with no approval asked', (tester) async {
      final harness = await _openPropose(tester);

      await _toShow(tester);

      expect(harness.approval.reasons, isEmpty);
      final header = tester.widget<ShellSheetHeader>(_inSheet(find.byType(ShellSheetHeader)));
      expect((header.parent?.title, header.title), ('Propose', 'Sign with Cold Wallet'));
      expect(find.byType(AnimatedUrQr), findsOneWidget);
      expect(harness.chain.proposals, isEmpty);
      expect(harness.chain.signedProposals, isEmpty);
    });
  });

  group('signing', () {
    testOnMac('the request is the member\'s, for the amount and the whole address over its checkphrase', (
      tester,
    ) async {
      final harness = await _openPropose(tester);

      await _toShow(tester);

      expect(tester.widget<AnimatedUrQr>(find.byType(AnimatedUrQr)).parts, ['UR:QUANTUS-SIGN-REQUEST/qzVault/1249990']);
      expect(harness.chain.signRequests, hasLength(1));
      expect(_inSheet(find.text('250 QTC')), findsOneWidget);
      expect(_inSheet(find.text('qzPayee')), findsOneWidget);
      expect(_inSheet(find.text('Phrase-qzPayee')), findsOneWidget);
    });

    testOnMac('the header names the account that signs, the cold wallet\'s', (tester) async {
      await _openPropose(tester);

      await _toShow(tester);

      expect(tester.widget<ShellSheetHeader>(_inSheet(find.byType(ShellSheetHeader))).account, vaultAccount);
    });

    testOnMac('a good signature is handed over once, as the multisig\'s proposal signed by its member', (tester) async {
      final harness = await _openPropose(tester);
      final shown = fakeUnsignedTransaction();
      harness.chain.unsigned = (_) async => shown;
      await _toShow(tester);

      await _signOnColdWallet(tester, harness.camera);

      final sent = harness.chain.signedProposals.single;
      expect(
        (sent.multisig, sent.signer, sent.recipient, sent.amount, sent.expiryBlock),
        ('qzColdTeam', 'qzVault', 'qzPayee', _qtc(250), FakeSendChain.usualProposalCost.expiryBlock),
      );
      expect(sent.unsigned, same(shown));
      expect(sent.signature, same(harness.chain.signature));
      expect(harness.chain.proposals, isEmpty);
    });

    testOnMac('"I rejected it on the cold wallet" returns to the review, nothing proposed', (tester) async {
      final harness = await _openPropose(tester);
      await _toShow(tester);
      await _tap(tester, KeystoneSigningView.continueKey);
      await _tap(tester, KeystoneSigningView.mismatchKey);

      await _tap(tester, KeystoneSigningView.rejectedKey);

      expect(find.byKey(SendSheet.sendKey), findsOneWidget);
      expect(harness.chain.signedProposals, isEmpty);
    });
  });

  group('the receipt', () {
    testOnMac('says it is proposing until the wallet sees the proposal created, then what was proposed', (
      tester,
    ) async {
      final harness = await _openPropose(tester);
      await _toShow(tester);

      await _signOnColdWallet(tester, harness.camera);

      expect(_inSheet(find.text('Proposing 250 QTC')), findsOneWidget);
      expect(_inSheet(find.text('Waiting for the network to create the proposal.')), findsOneWidget);
      expect(_inSheet(find.text('0 of 2')), findsOneWidget);

      await _created(tester);

      expect(_inSheet(find.text('250 QTC proposed')), findsOneWidget);
      expect(_inSheet(find.text('1 of 2')), findsOneWidget);
    });

    testOnMac('View in Explorer opens the created proposal', (tester) async {
      final harness = await _openPropose(tester);
      await _toShow(tester);
      await _signOnColdWallet(tester, harness.camera);

      await _tap(tester, SendSheet.explorerKey);

      expect(harness.opened, [Uri.parse('${AppConstants.explorerEndpoint}/multisig-proposal-created/0xhash')]);
    });

    testOnMac('the address paid is kept among those paid before', (tester) async {
      final harness = await _openPropose(tester);
      await _toShow(tester);

      await _signOnColdWallet(tester, harness.camera);

      expect(harness.chain.recents.first, 'qzPayee');
    });
  });
}
