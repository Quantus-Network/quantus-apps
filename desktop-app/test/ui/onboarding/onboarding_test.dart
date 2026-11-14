import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_desktop_wallet/ui/components/window_drag_area.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/import_wallet_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/wallet_created_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

const _twelveWords = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

const _root = Account(walletIndex: 0, index: 0, name: 'Account 1', accountId: 'qzRoot');
const _found = Account(walletIndex: 0, index: 3, name: 'Account 4', accountId: 'qzFound');
const _encrypted = Account(
  walletIndex: 0,
  index: AppConstants.encryptedAccountIndex,
  name: 'Encrypted Account',
  accountId: 'qzEncrypted0',
  accountType: AccountType.encrypted,
);

Finder _button(String label) => find.widgetWithText(QuantusButton, label);

bool _isEnabled(WidgetTester tester, String label) => !tester.widget<QuantusButton>(_button(label)).isDisabled;

/// A button showing a spinner in place of its label.
final _busyButton = find.byWidgetPredicate((widget) => widget is QuantusButton && widget.isLoading);

/// Lets work under way and a dialog's entrance finish while a spinner, which
/// never settles, is on screen.
Future<void> _pumpWhileBusy(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _inSidebar(String text) => find.descendant(of: find.byType(Sidebar), matching: find.text(text));

Finder _inPaneHeader(String text) => find.descendant(of: find.byType(PaneHeader), matching: find.text(text));

Future<void> _openImport(WidgetTester tester) async {
  await tester.tap(_button('Import Wallet'));
  await tester.pumpAndSettle();
}

Future<void> _typePhrase(WidgetTester tester, String phrase) async {
  await tester.enterText(find.byType(EditableText), phrase);
  await tester.pump();
}

void main() {
  group('at start', () {
    testOnMac('with no wallet the window shows Welcome, not the sidebar or the account header', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);
      expect(find.byType(PaneHeader), findsNothing);
    });

    testOnMac('with a wallet the window shows the shell, not Welcome', (tester) async {
      final device = FakeWalletDevice()..store([_root, _encrypted]);
      await pumpShell(tester, overrides: device.overrides);

      expect(find.byType(Sidebar), findsOneWidget);
      expect(_inPaneHeader('Account 1'), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
    });

    testOnMac('while the check for a wallet runs the window shows a loader and neither of them', (tester) async {
      final device = FakeWalletDevice()..storage.hasWalletGate = Completer<void>().future;
      await pumpShell(tester, overrides: device.overrides, settle: false);

      expect(find.byType(Loader), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.byType(Sidebar), findsNothing);
    });

    testOnMac('a check for a wallet that fails says why, is not repeated, and shows neither Welcome nor the shell', (
      tester,
    ) async {
      final device = FakeWalletDevice()..storage.hasWalletError = Exception('storage is gone');
      await pumpShell(tester, overrides: device.overrides);

      expect(find.text('Exception: storage is gone'), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.byType(Sidebar), findsNothing);

      // Asking again could prompt for the keychain again, so it is asked once.
      await tester.pump(const Duration(seconds: 30));

      expect(device.storage.hasWalletChecks, 1);
    });

    testOnMac('a wallet whose recovery phrase is gone says so, and OK wipes it and shows Welcome', (tester) async {
      final device = FakeWalletDevice()..store([_root, _encrypted], mnemonic: null);
      await pumpShell(tester, overrides: device.overrides, settle: false);
      await tester.pump();
      await tester.pump();

      expect(find.text('Wallet Error'), findsOneWidget);
      expect(find.text('Unable to find secret phrase. Please restore your wallet.'), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);
      expect(device.logouts, 0);

      await tester.tap(_button('OK'));
      await tester.pumpAndSettle();

      expect(device.logouts, 1);
      expect(find.text('Wallet Error'), findsNothing);
      expect(find.byType(WelcomePage), findsOneWidget);
    });

    testOnMac('an account scan left unfinished is finished, and the accounts it finds are listed', (tester) async {
      final device = FakeWalletDevice()
        ..store([_root, _encrypted])
        ..storage.pendingScans[0] = _root.accountId
        ..scan = () async => [_root, _found];
      await pumpShell(tester, overrides: device.overrides);

      expect(device.scans, 1);
      expect(device.storage.pendingScans, isEmpty);
      expect(_inSidebar('Account 3'), findsOneWidget);
    });

    testOnMac('a wallet with no account scan pending is not scanned', (tester) async {
      final device = FakeWalletDevice()..store([_root, _encrypted]);
      await pumpShell(tester, overrides: device.overrides);

      expect(device.scans, 0);
    });

    testOnMac('a software wallet that lacks its encrypted account gets it, and it is listed', (tester) async {
      final device = FakeWalletDevice()..store([_root]);
      await pumpShell(tester, overrides: device.overrides);

      expect(device.storage.accounts.map((a) => a.accountId), ['qzRoot', 'qzEncrypted0']);
      expect(_inSidebar('Encrypted Account'), findsOneWidget);
    });
  });

  group('Welcome', () {
    testOnMac('shows the logo, the tagline, Create New Wallet and Import Wallet', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      expect(find.image(const AssetImage('assets/quantus_orange_logo.png')), findsOneWidget);
      expect(find.text('Quantum Secure Encrypted Money'), findsOneWidget);
      expect(_isEnabled(tester, 'Create New Wallet'), isTrue);
      expect(_isEnabled(tester, 'Import Wallet'), isTrue);
    });

    testOnMac('while the wallet is created, Create New Wallet is busy and Import Wallet is disabled', (tester) async {
      final generated = Completer<String>();
      final device = FakeWalletDevice()..generateMnemonic = () => generated.future;
      await pumpShell(tester, overrides: device.overrides);

      await tester.tap(_button('Create New Wallet'));
      await tester.pump();

      expect(_busyButton, findsOneWidget);
      expect(find.text('Create New Wallet'), findsNothing);
      expect(_isEnabled(tester, 'Import Wallet'), isFalse);

      generated.complete(_twelveWords);
      await tester.pumpAndSettle();

      expect(find.byType(WalletCreatedPage), findsOneWidget);
    });

    testOnMac('a created wallet is announced with its two accounts, and Go to Wallet opens it', (tester) async {
      final device = FakeWalletDevice();
      await pumpShell(tester, overrides: device.overrides);

      await tester.tap(_button('Create New Wallet'));
      await tester.pumpAndSettle();

      expect(device.storage.mnemonics, {0: 'created wallet recovery phrase'});
      expect(find.text('Wallet Created'), findsOneWidget);
      expect(find.text('Two accounts were created for you.'), findsOneWidget);
      expect(find.widgetWithText(InfoCard, 'Account 1'), findsOneWidget);
      expect(find.widgetWithText(InfoCard, 'Encrypted Account'), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);

      await tester.tap(_button('Go to Wallet'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletCreatedPage), findsNothing);
      expect(_inPaneHeader('Account 1'), findsOneWidget);
      expect(_inSidebar('Account 1'), findsOneWidget);
      expect(_inSidebar('Encrypted Account'), findsOneWidget);
    });

    testOnMac('a failed creation is reported on Welcome, and both buttons work again', (tester) async {
      final device = FakeWalletDevice()..generateMnemonic = () async => throw StateError('no entropy');
      await pumpShell(tester, overrides: device.overrides);

      await tester.tap(_button('Create New Wallet'));
      await tester.pumpAndSettle();

      expect(find.text('Error saving wallet: Bad state: no entropy'), findsOneWidget);
      expect(find.byType(WelcomePage), findsOneWidget);
      expect(_busyButton, findsNothing);
      expect(_isEnabled(tester, 'Create New Wallet'), isTrue);
      expect(_isEnabled(tester, 'Import Wallet'), isTrue);

      device.generateMnemonic = () async => _twelveWords;
      await tester.tap(_button('Create New Wallet'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletCreatedPage), findsOneWidget);
    });
  });

  group('Import Wallet', () {
    testOnMac('opens from Welcome, with Import disabled until a phrase is typed', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      await _openImport(tester);

      expect(find.byType(ImportWalletPage), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.text('Restore an existing wallet with your 12 or 24 words recovery phrase'), findsOneWidget);
      expect(_isEnabled(tester, 'Import'), isFalse);

      await _typePhrase(tester, 'abandon');

      expect(_isEnabled(tester, 'Import'), isTrue);
    });

    testOnMac('Back returns to Welcome', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _openImport(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(ImportWalletPage), findsNothing);
    });

    testOnMac('Esc returns to Welcome', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _openImport(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomePage), findsOneWidget);
    });

    testOnMac('a phrase of the wrong length is refused where it was typed', (tester) async {
      final device = FakeWalletDevice();
      await pumpShell(tester, overrides: device.overrides);
      await _openImport(tester);

      await _typePhrase(tester, 'abandon abandon about');
      await tester.tap(_button('Import'));
      await tester.pumpAndSettle();

      expect(find.text('Recovery phrase must be 12 or 24 words'), findsOneWidget);
      expect(find.byType(ImportWalletPage), findsOneWidget);
      expect(device.storage.mnemonics, isEmpty);
    });

    testOnMac('a valid phrase is busy while its accounts are looked up, then opens the wallet', (tester) async {
      final scanned = Completer<List<Account>>();
      final device = FakeWalletDevice()..scan = () => scanned.future;
      await pumpShell(tester, overrides: device.overrides);
      await _openImport(tester);

      await _typePhrase(tester, _twelveWords);
      await tester.tap(_button('Import'));
      await tester.pump();

      expect(_busyButton, findsOneWidget);
      expect(find.text('Import'), findsNothing);
      expect(find.byType(Sidebar), findsNothing);

      scanned.complete([]);
      await tester.pumpAndSettle();

      expect(device.storage.mnemonics, {0: _twelveWords});
      expect(find.byType(ImportWalletPage), findsNothing);
      expect(_inPaneHeader('Account 1'), findsOneWidget);
      expect(_inSidebar('Account 1'), findsOneWidget);
    });

    testOnMac('the wallet opens without waiting for its encrypted account, which is listed once restored', (
      tester,
    ) async {
      final restored = Completer<void>();
      final device = FakeWalletDevice()..storage.encryptedAccountsGate = restored.future;
      await pumpShell(tester, overrides: device.overrides);
      await _openImport(tester);

      await _typePhrase(tester, _twelveWords);
      await tester.tap(_button('Import'));
      await tester.pumpAndSettle();

      expect(_inSidebar('Account 1'), findsOneWidget);
      expect(_inSidebar('Encrypted Account'), findsNothing);

      restored.complete();
      await tester.pumpAndSettle();

      expect(_inSidebar('Encrypted Account'), findsOneWidget);
    });

    testOnMac('a failed account scan asks what to do; Try again scans again and opens the wallet', (tester) async {
      var attempts = 0;
      final device = FakeWalletDevice();
      device.scan = () async => ++attempts == 1 ? throw StateError('offline') : [];
      await pumpShell(tester, overrides: device.overrides);
      await _openImport(tester);

      await _typePhrase(tester, _twelveWords);
      await tester.tap(_button('Import'));
      await _pumpWhileBusy(tester);

      expect(find.text('Account scan failed'), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);

      await tester.tap(_button('Try again'));
      await tester.pumpAndSettle();

      expect(device.scans, 2);
      expect(find.text('Account scan failed'), findsNothing);
      expect(device.storage.pendingScans, isEmpty);
      expect(_inPaneHeader('Account 1'), findsOneWidget);
    });

    testOnMac('Skip after a failed account scan opens the wallet and leaves the scan for the next start', (
      tester,
    ) async {
      final device = FakeWalletDevice()..scan = () async => throw StateError('offline');
      await pumpShell(tester, overrides: device.overrides);
      await _openImport(tester);

      await _typePhrase(tester, _twelveWords);
      await tester.tap(_button('Import'));
      await _pumpWhileBusy(tester);
      await tester.tap(_button('Skip'));
      await tester.pumpAndSettle();

      expect(device.scans, 1);
      expect(device.storage.pendingScans, {0: 'qz(abandon)'});
      expect(_inPaneHeader('Account 1'), findsOneWidget);
    });

    testOnMac('any other failure is shown where the phrase was typed', (tester) async {
      final device = FakeWalletDevice()..storage.mnemonicWriteError = StateError('keychain is locked');
      await pumpShell(tester, overrides: device.overrides);
      await _openImport(tester);

      await _typePhrase(tester, _twelveWords);
      await tester.tap(_button('Import'));
      await tester.pumpAndSettle();

      expect(find.text('Bad state: keychain is locked'), findsOneWidget);
      expect(find.byType(ImportWalletPage), findsOneWidget);
      expect(_busyButton, findsNothing);
    });
  });

  group('the window during onboarding', () {
    testOnMac('the top of every onboarding page drags the window', (tester) async {
      final requests = recordWindowRequests(tester);
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      await tester.dragFrom(const Offset(600, 26), const Offset(80, 30));
      await tester.pumpAndSettle();
      await _openImport(tester);
      await tester.dragFrom(const Offset(600, 26), const Offset(80, 30));
      await tester.pumpAndSettle();

      expect(requests, ['startDrag', 'startDrag']);
    });

    testOnMac('dragging below the top strip does not move the window', (tester) async {
      final requests = recordWindowRequests(tester);
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      await tester.dragFrom(const Offset(100, shellHeaderHeight + 40), const Offset(80, 30));
      await tester.pumpAndSettle();

      expect(requests, isEmpty);
    });

    testOnMac('Back sits clear of the traffic lights, in the middle of the top strip', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _openImport(tester);

      final back = tester.getRect(find.byTooltip('Back'));
      expect(back.left, greaterThanOrEqualTo(trafficLightsInset));
      expect(back.center.dy, moreOrLessEquals(shellHeaderHeight / 2));
    });

    testOnWindowsAndLinux('there is no drag area, and Back starts at the window\'s edge', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _openImport(tester);

      expect(find.byType(WindowDragArea), findsNothing);
      expect(tester.getRect(find.byTooltip('Back')).left, lessThan(trafficLightsInset));
    });
  });
}
