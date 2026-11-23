import 'dart:async';
import 'dart:io';

import 'package:desktop_qr_camera/desktop_qr_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/qr_scan_source.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/accounts/connect_cold_wallet_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/account_actions.dart';

import '../../fakes.dart';

const _cold = 'qzColdAddress';
const _other = 'qzOtherAddress';

class _FakeScanSource implements QrScanSource {
  final _reads = StreamController<String>.broadcast(sync: true);

  /// What the next start fails with.
  Object? startError;
  bool isOn = false;
  bool isDisposed = false;
  int starts = 0;

  @override
  Stream<String> get reads => _reads.stream;

  @override
  Future<void> start() async {
    starts++;
    if (startError case final error?) {
      startError = null;
      throw error;
    }
    isOn = true;
  }

  @override
  Future<void> stop() async => isOn = false;

  @override
  Widget buildPreview() => const SizedBox.expand(key: Key('camera-preview'));

  @override
  Future<void> dispose() async {
    isOn = false;
    isDisposed = true;
  }

  void read(String text) => _reads.add(text);

  void fail(QrCameraFailure failure) {
    isOn = false;
    _reads.addError(QrCameraException(failure));
  }
}

class _Harness {
  _Harness(this.device, this.source, this.openedUrls);

  final FakeWalletDevice device;
  final _FakeScanSource source;
  final List<Uri> openedUrls;
}

/// Main and Savings in Wallet 1 and Vault in a Cold Wallet, so the next free
/// wallet index is 2.
Future<_Harness> _pump(WidgetTester tester, {bool offered = true, List<MultisigAccount> multisigs = const []}) async {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.accounts.add(vaultAccount);
  device.storage.multisigStore.addAll(multisigs);
  if (!offered) device.remoteConfig = _withoutColdWallets;
  final source = _FakeScanSource();
  final opened = <Uri>[];
  await pumpShell(
    tester,
    overrides: [
      ...device.overrides,
      systemApprovalProvider.overrideWithValue(FakeUserApproval()),
      sensitiveClipboardProvider.overrideWithValue(FakeSensitiveClipboard()),
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) => FakeEncryptedAccountService(() async => 'qzDeposit', innerHash: () async => '0xinner'),
      ),
      qrScanSourceFactoryProvider.overrideWithValue(() => source),
      openExternalUrlProvider.overrideWithValue((url) async => opened.add(url)),
    ],
  );
  return _Harness(device, source, opened);
}

const _withoutColdWallets = RemoteConfigModel(
  enableTestButtons: false,
  enableKeystoneHardwareWallet: false,
  enableHighSecurity: false,
  enableRemoteNotifications: true,
  enableEncryptedAccount: true,
  enableMultisig: true,
  enableOneClickNearWarning: true,
  geoNearAllowed: true,
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inSidebar(Finder matching) => find.descendant(of: find.byType(Sidebar), matching: matching);

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder get _addRow => _inSidebar(find.widgetWithText(SidebarRow, 'Add Account'));

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

Finder get _sheet => find.byType(ConnectColdWalletSheet);

Finder _button(String label) => _inSheet(find.widgetWithText(QuantusButton, label));

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_addRow);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: _menu, matching: find.text('Connect Cold Wallet…')));
  await tester.pumpAndSettle();
}

Future<void> _readThreeTimes(WidgetTester tester, _FakeScanSource source, [String address = _cold]) async {
  for (var read = 0; read < 3; read++) {
    source.read(address);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(_button(label));
  await tester.pumpAndSettle();
}

List<PlatformMenuItem> _accountMenuItems(WidgetTester tester) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  return [
    for (final entry in menus.singleWhere((menu) => menu.label == 'Account').menus)
      if (entry is PlatformMenuItemGroup) ...entry.members else entry,
  ];
}

Account? _saved(_Harness harness) => harness.device.storage.accounts.where((a) => a.accountId == _cold).firstOrNull;

void main() {
  group('where it is offered', () {
    testOnMac('the Add Account menu has it right after Import Wallet…', (tester) async {
      await _pump(tester);

      await tester.tap(_addRow);
      await tester.pumpAndSettle();

      final labels = [
        for (final row in tester.widgetList<MenuPanelRow>(
          find.descendant(of: _menu, matching: find.byType(MenuPanelRow)),
        ))
          row.label,
      ];
      expect(labels, [
        'New Account',
        'Import Wallet…',
        'Connect Cold Wallet…',
        'Create Multisig…',
        'Manage Multisigs…',
      ]);
    });

    testOnMac('the Account menu has it, and it opens the sheet', (tester) async {
      await _pump(tester);

      _accountMenuItems(tester).singleWhere((item) => item.label == 'Connect Cold Wallet…').onSelected!();
      await tester.pumpAndSettle();

      expect(_sheet, findsOneWidget);
    });

    testOnMac('with cold wallets turned off, neither menu has it and it does not open', (tester) async {
      await _pump(tester, offered: false);

      expect(_accountMenuItems(tester).map((item) => item.label), isNot(contains('Connect Cold Wallet…')));
      await tester.tap(_addRow);
      await tester.pumpAndSettle();
      expect(find.descendant(of: _menu, matching: find.text('Connect Cold Wallet…')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _container(tester).read(shellSheetProvider.notifier).open(ShellSheet.connectColdWallet);
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
    });
  });

  group('the camera', () {
    testWidgets('opening the sheet shows the steps and turns the camera on', (tester) async {
      final harness = await _pump(tester);

      await _open(tester);

      expect(harness.source.isOn, isTrue);
      expect(find.byKey(const Key('camera-preview')), findsOneWidget);
      expect(_inSheet(find.text('Unlock your cold wallet')), findsOneWidget);
      expect(_inSheet(find.text('Show your account QR code')), findsOneWidget);
      expect(_inSheet(find.text('Hold it up to this camera')), findsOneWidget);
      expect(_inSheet(find.text('Looking for a QR code')), findsOneWidget);
    });

    testWidgets('Cancel closes the sheet and turns the camera off', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);

      await _tapButton(tester, 'Cancel');

      expect(_sheet, findsNothing);
      expect(harness.source.isOn, isFalse);
      expect(harness.source.isDisposed, isTrue);
    });

    testWidgets('the close cross turns the camera off', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);

      await tester.tap(_inSheet(find.byKey(ShellSheetHeader.closeGlyphKey)));
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(harness.source.isOn, isFalse);
    });

    testWidgets('Escape turns the camera off', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(harness.source.isOn, isFalse);
    });

    for (final (failure, title, body) in [
      (QrCameraFailure.noCamera, 'No camera found', 'Connect a camera to this computer, then try again.'),
      (QrCameraFailure.busy, 'The camera is in use', 'Close the other app using it, then try again.'),
      (QrCameraFailure.unsupported, "This camera can't be used", 'It offers no picture format this app can read.'),
      (
        QrCameraFailure.mediaUnavailable,
        'Camera support is missing',
        'Install the Media Feature Pack for Windows, then try again.',
      ),
      (QrCameraFailure.failed, "Couldn't use the camera", 'Something went wrong with the camera. Try again.'),
    ]) {
      testWidgets('${failure.name} says so, and Try Again turns the camera on', (tester) async {
        final harness = await _pump(tester);
        harness.source.startError = QrCameraException(failure);

        await _open(tester);

        expect(_inSheet(find.text(title)), findsOneWidget);
        expect(_inSheet(find.text(body)), findsOneWidget);
        expect(_inSheet(find.text('Looking for a QR code')), findsNothing);

        await _tapButton(tester, 'Try Again');

        expect(harness.source.isOn, isTrue);
        expect(_inSheet(find.text(title)), findsNothing);
        expect(_inSheet(find.text('Looking for a QR code')), findsOneWidget);
      });
    }

    testOnMac('permission off says where to allow it and opens System Settings', (tester) async {
      final harness = await _pump(tester);
      harness.source.startError = const QrCameraException(QrCameraFailure.permissionDenied);

      await _open(tester);

      expect(_inSheet(find.text('Camera access is off')), findsOneWidget);
      expect(_inSheet(find.text('Allow Quantus Wallet under Privacy & Security, Camera.')), findsOneWidget);

      await _tapButton(tester, 'Open System Settings');

      expect(
        harness.openedUrls.single.toString(),
        'x-apple.systempreferences:com.apple.preference.security?Privacy_Camera',
      );
      expect(_button('Try Again'), findsOneWidget);
    });

    testWidgets('permission off on Windows opens its camera privacy page', (tester) async {
      final harness = await _pump(tester);
      harness.source.startError = const QrCameraException(QrCameraFailure.permissionDenied);

      await _open(tester);
      expect(_inSheet(find.text('Allow camera access under Privacy & security, Camera.')), findsOneWidget);
      await _tapButton(tester, 'Open System Settings');

      expect(harness.openedUrls.single.toString(), 'ms-settings:privacy-webcam');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('permission off on Linux has no settings page to open', (tester) async {
      final harness = await _pump(tester);
      harness.source.startError = const QrCameraException(QrCameraFailure.permissionDenied);

      await _open(tester);

      expect(_inSheet(find.text('Check that your user is allowed to use the camera.')), findsOneWidget);
      expect(_button('Open System Settings'), findsNothing);
      expect(_button('Try Again'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a camera that stops mid-scan says so, and Try Again needs three new reads', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      harness.source.read(_cold);
      harness.source.read(_cold);

      harness.source.fail(QrCameraFailure.stopped);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('The camera stopped')), findsOneWidget);

      await _tapButton(tester, 'Try Again');
      harness.source.read(_cold);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('Confirm Address')), findsNothing);
    });

    testWidgets('fits the smallest window', (tester) async {
      final harness = await _pump(tester);
      tester.view.physicalSize = const Size(960, 640);
      await tester.pumpAndSettle();

      await _open(tester);
      expect(tester.takeException(), isNull);

      await _readThreeTimes(tester, harness.source);
      expect(tester.takeException(), isNull);
    });
  });

  group('reading', () {
    testWidgets('a code that is not an address says so and keeps scanning', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);

      harness.source.read('https://example.com');
      await tester.pump();

      expect(_inSheet(find.text("That QR code isn't an account address.")), findsOneWidget);
      expect(harness.source.isOn, isTrue);

      harness.source.read(_cold);
      await tester.pump();

      expect(_inSheet(find.text("That QR code isn't an account address.")), findsNothing);
    });

    testWidgets('an account already in the app is refused on the scan step', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);

      await _readThreeTimes(tester, harness.source, mainAccount.accountId);

      expect(_inSheet(find.text('That account is already in this app.')), findsOneWidget);
      expect(_inSheet(find.text('Confirm Address')), findsNothing);
      expect(harness.source.isOn, isTrue);
    });

    testWidgets('a multisig already in the app is refused on the scan step', (tester) async {
      final harness = await _pump(tester, multisigs: [teamMultisig]);
      await _open(tester);

      await _readThreeTimes(tester, harness.source, teamMultisig.accountId);

      expect(_inSheet(find.text('That account is already in this app.')), findsOneWidget);
    });

    testWidgets('a third matching read turns the camera off and shows the address, saving nothing', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);

      await _readThreeTimes(tester, harness.source);

      expect(harness.source.isOn, isFalse);
      expect(_inSheet(find.text('Confirm Address')), findsOneWidget);
      expect(_inSheet(find.textContaining(_cold, findRichText: true)), findsWidgets);
      expect(_inSheet(find.text('Cold Wallet')), findsOneWidget);
      expect(_saved(harness), isNull);
    });

    testWidgets('Scan Again turns the camera on and needs three new reads', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      await _readThreeTimes(tester, harness.source);

      await _tapButton(tester, 'Scan Again');

      expect(harness.source.isOn, isTrue);
      expect(_inSheet(find.text('Confirm Address')), findsNothing);

      harness.source.read(_cold);
      harness.source.read(_cold);
      await tester.pumpAndSettle();
      expect(_inSheet(find.text('Confirm Address')), findsNothing);

      harness.source.read(_cold);
      await tester.pumpAndSettle();
      expect(_inSheet(find.text('Confirm Address')), findsOneWidget);
    });

    testWidgets('the way back from Confirm Address scans again', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      await _readThreeTimes(tester, harness.source);

      await tester.tap(_inSheet(find.byKey(ShellSheetHeader.backKey)));
      await tester.pumpAndSettle();

      expect(harness.source.isOn, isTrue);
      expect(_inSheet(find.text('Confirm Address')), findsNothing);
    });

    testWidgets('closing from Confirm Address saves nothing', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      await _readThreeTimes(tester, harness.source);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(_saved(harness), isNull);
    });
  });

  group('connecting', () {
    testWidgets('Connect adds a new cold wallet, makes it active and closes', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      await _readThreeTimes(tester, harness.source);

      await _tapButton(tester, 'Connect');

      expect(_sheet, findsNothing);
      final saved = _saved(harness)!;
      expect(saved.walletIndex, 2);
      expect(saved.index, 0);
      expect(saved.name, 'Cold Wallet');
      expect(saved.accountType, AccountType.keystone);
      final container = _container(tester);
      expect(container.read(activeAccountProvider).value?.account.accountId, _cold);
      expect(container.read(keptOpenWalletsProvider), contains(2));
      expect(_inSidebar(find.text('Cold Wallet')), findsWidgets);
    });

    testWidgets('a connected account can receive, but not send, swap or create a multisig', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      await _readThreeTimes(tester, harness.source);
      await _tapButton(tester, 'Connect');

      final container = _container(tester);
      final actions = container.read(activeAccountActionsProvider);
      bool isEnabled(AccountActionKind kind) => actions.where((a) => a.kind == kind && a.isEnabled).isNotEmpty;

      expect(isEnabled(AccountActionKind.receive), isTrue);
      expect(isEnabled(AccountActionKind.send), isFalse);
      expect(isEnabled(AccountActionKind.swap), isFalse);
      expect(container.read(multisigCreatorProvider), isNull);
    });

    testWidgets('an address added while confirming is refused on Connect', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      await _readThreeTimes(tester, harness.source);
      harness.device.storage.accounts.add(const Account(walletIndex: 5, index: 0, name: 'Elsewhere', accountId: _cold));

      await _tapButton(tester, 'Connect');

      expect(_sheet, findsOneWidget);
      expect(_inSheet(find.text('That account is already in this app.')), findsOneWidget);
      expect(harness.device.storage.accounts.where((a) => a.accountId == _cold), hasLength(1));
    });

    testWidgets('a failed save stays on Confirm Address, says so, and can be retried', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      await _readThreeTimes(tester, harness.source);
      harness.device.storage.addAccountError = Exception('disk full');

      await _tapButton(tester, 'Connect');

      expect(_sheet, findsOneWidget);
      expect(_inSheet(find.text("Couldn't connect this cold wallet")), findsOneWidget);
      expect(_saved(harness), isNull);

      harness.device.storage.addAccountError = null;
      await _tapButton(tester, 'Connect');

      expect(_sheet, findsNothing);
      expect(_saved(harness), isNotNull);
    });

    testWidgets('after a failed save, Scan Again still works', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      await _readThreeTimes(tester, harness.source);
      harness.device.storage.addAccountError = Exception('disk full');
      await _tapButton(tester, 'Connect');

      await _tapButton(tester, 'Scan Again');
      await _readThreeTimes(tester, harness.source, _other);

      expect(_inSheet(find.text("Couldn't connect this cold wallet")), findsNothing);
      expect(_inSheet(find.textContaining(_other, findRichText: true)), findsWidgets);
    });

    testWidgets('Connect pressed twice saves once, and the sheet cannot close while saving', (tester) async {
      final harness = await _pump(tester);
      await _open(tester);
      await _readThreeTimes(tester, harness.source);
      final gate = Completer<void>();
      harness.device.storage.addAccountGate = gate.future;

      await tester.tap(_button('Connect'));
      await tester.pump();
      await tester.tap(_button('Connect'), warnIfMissed: false);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(_sheet, findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
      expect(harness.device.storage.accounts.where((a) => a.accountId == _cold), hasLength(1));
    });
  });

  group('macOS permissions', () {
    test('the app asks for the camera and never the microphone', () {
      final info = File('macos/Runner/Info.plist').readAsStringSync();
      expect(info, contains('NSCameraUsageDescription'));
      expect(info, isNot(contains('NSMicrophoneUsageDescription')));

      for (final name in ['DebugProfile', 'Release']) {
        final entitlements = File('macos/Runner/$name.entitlements').readAsStringSync();
        expect(
          RegExp(r'<key>com\.apple\.security\.device\.camera</key>\s*<true/>').hasMatch(entitlements),
          isTrue,
          reason: name,
        );
        expect(entitlements, isNot(contains('device.audio-input')), reason: name);
        expect(entitlements, isNot(contains('device.microphone')), reason: name);
      }
    });
  });
}
