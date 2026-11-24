import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/qr_scan_source.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/accounts/create_multisig_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/keystone/keystone_signing_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

const _other = 'qzOtherSigner';
const _third = 'qzThirdSigner';

/// The address the fake chain gives Vault, [_other] and [_third] at two
/// approvals.
final _threeSigners = FakeSendChain.newMultisigAddress(3, 2, BigInt.zero);

class _Harness {
  _Harness(this.device, this.approval, this.camera);

  final FakeWalletDevice device;
  final FakeUserApproval approval;
  final FakeScanSource camera;
}

/// Opens the wallet on Vault, whose key is on a cold wallet.
Future<_Harness> _pump(WidgetTester tester, {FakeUserApproval? approval}) async {
  approval ??= FakeUserApproval();
  final camera = FakeScanSource();
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.accounts.add(vaultAccount);
  device.storage.activeAccount = const RegularAccount(vaultAccount);
  await pumpShell(
    tester,
    overrides: [
      ...device.overrides,
      systemApprovalProvider.overrideWithValue(approval),
      animatedQrScanSourceFactoryProvider.overrideWithValue(() => camera),
    ],
  );
  return _Harness(device, approval, camera);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder get _sheet => find.byType(CreateMultisigSheet);

Finder get _addRow =>
    find.descendant(of: find.byType(Sidebar), matching: find.widgetWithText(SidebarRow, 'Add Account'));

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

Finder _editable(Key key) => find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

PlatformMenuItem _menuBarItem(WidgetTester tester) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  return [
    for (final entry in menus.singleWhere((menu) => menu.label == 'Account').menus)
      if (entry is PlatformMenuItemGroup) ...entry.members else entry,
  ].whereType<PlatformMenuItem>().singleWhere((item) => item.label == 'Create Multisig…');
}

bool _canPress(WidgetTester tester, Key key) {
  final button = tester.widget<SheetButton>(find.byKey(key));
  return !button.isDisabled && !button.isLoading;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Opens Create Multisig from Add Account and adds two more signers.
Future<void> _openFilled(WidgetTester tester) async {
  await tester.tap(_addRow);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: _menu, matching: find.text('Create Multisig…')));
  await tester.pumpAndSettle();
  for (final address in [_other, _third]) {
    await tester.enterText(_editable(CreateMultisigSheet.signerFieldKey), address);
    await tester.pump();
    await _tap(tester, CreateMultisigSheet.addSignerKey);
  }
}

/// From the filled form, Review then Create: the request QR code is shown.
Future<void> _toShow(WidgetTester tester) async {
  await _openFilled(tester);
  await _tap(tester, CreateMultisigSheet.reviewKey);
  await _tap(tester, CreateMultisigSheet.createKey);
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('opening Create Multisig', () {
    testOnMac('an account whose key is on a cold wallet creates, and can from both menus', (tester) async {
      await _pump(tester);

      expect(_container(tester).read(multisigCreatorProvider), vaultAccount);
      expect(_menuBarItem(tester).onSelected, isNotNull);
      await tester.tap(_addRow);
      await tester.pumpAndSettle();
      expect(tester.widget<MenuPanelRow>(find.widgetWithText(MenuPanelRow, 'Create Multisig…')).isDisabled, isFalse);
    });

    testOnMac('Review is available where this Mac cannot approve, and the form says nothing of approval', (
      tester,
    ) async {
      await _pump(tester, approval: FakeUserApproval()..availabilityAnswer = ApprovalAvailability.notSetUp);

      await _openFilled(tester);

      expect(find.text('Set up a login password for this Mac to use this.'), findsNothing);
      expect(_canPress(tester, CreateMultisigSheet.reviewKey), isTrue);
    });
  });

  group('Create, then signing', () {
    testOnMac('Create checks the chain again, then opens the signing steps, with no approval asked', (tester) async {
      final harness = await _pump(tester);

      await _toShow(tester);

      expect(harness.approval.reasons, isEmpty);
      final header = tester.widget<ShellSheetHeader>(_inSheet(find.byType(ShellSheetHeader)));
      expect(
        (header.parent?.title, header.title, header.account),
        ('Create Multisig', 'Sign with Cold Wallet', vaultAccount),
      );
      expect(find.byType(AnimatedUrQr), findsOneWidget);
      expect(harness.device.chain.createdMultisigs, isEmpty);
      expect(harness.device.chain.externallySignedCreations, isEmpty);
    });

    testOnMac('an address taken by the time of Create returns to the form, and nothing is signed', (tester) async {
      final harness = await _pump(tester);
      await _openFilled(tester);
      await _tap(tester, CreateMultisigSheet.reviewKey);
      harness.device.chain.indexedMultisigs.add(_threeSigners);

      await _tap(tester, CreateMultisigSheet.createKey);

      expect(find.text('A multisig with this address already exists on-chain.'), findsOneWidget);
      expect(find.byType(AnimatedUrQr), findsNothing);
      expect(harness.device.chain.signRequests, isEmpty);
    });

    testOnMac('the request is the creator\'s, for the creation, beside the action and the new address', (tester) async {
      final harness = await _pump(tester);

      await _toShow(tester);

      expect(tester.widget<AnimatedUrQr>(find.byType(AnimatedUrQr)).parts, ['UR:QUANTUS-SIGN-REQUEST/qzVault/1249990']);
      expect(harness.device.chain.signRequests, [(recipient: 'a new multisig', amount: null)]);
      expect(_inSheet(find.text('ACTION')), findsOneWidget);
      expect(_inSheet(find.text('Create 2 of 3 multisig')), findsOneWidget);
      expect(_inSheet(find.text(_threeSigners)), findsOneWidget);
      expect(_inSheet(find.text('Phrase-$_threeSigners')), findsOneWidget);
    });

    testOnMac('a good signature is handed over once as the creation, and the sheet closes on it being created', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _toShow(tester);

      await _signOnColdWallet(tester, harness.camera);

      expect(harness.device.chain.externallySignedCreations, hasLength(1));
      expect(harness.device.chain.createdMultisigs, isEmpty);
      expect(_sheet, findsNothing);
      final creating = _container(tester).read(pendingMultisigCreationsProvider);
      expect(creating.map((event) => event.multisigAddress), [_threeSigners]);
    });

    testOnMac('a hand-over that fails is said, the camera reads again, and nothing is left being created', (
      tester,
    ) async {
      final harness = await _pump(tester);
      await _toShow(tester);
      harness.device.chain.submitMultisig = () async => throw StateError('node down');

      await _signOnColdWallet(tester, harness.camera);

      expect(_inSheet(find.text('Couldn\'t read the signature. Please try again.')), findsOneWidget);
      expect(harness.camera.isOn, isTrue);
      expect(_container(tester).read(pendingMultisigCreationsProvider), isEmpty);
    });

    testOnMac('"I rejected it on the cold wallet" returns to the review, nothing created', (tester) async {
      final harness = await _pump(tester);
      await _toShow(tester);
      await _tap(tester, KeystoneSigningView.continueKey);
      await _tap(tester, KeystoneSigningView.mismatchKey);

      await _tap(tester, KeystoneSigningView.rejectedKey);

      expect(find.byKey(CreateMultisigSheet.createKey), findsOneWidget);
      expect(harness.device.chain.externallySignedCreations, isEmpty);
    });
  });
}
