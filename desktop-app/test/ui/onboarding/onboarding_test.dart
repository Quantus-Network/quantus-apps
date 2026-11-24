import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/components/window_drag_area.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/import_wallet_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/wallet_created_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

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

/// The sidebar's selected row, when it is [name]'s: the account the wallet
/// opened on.
Finder _selectedRow(String name) =>
    find.byWidgetPredicate((widget) => widget is SidebarRow && widget.isSelected && widget.title == name);

Future<void> _openImport(WidgetTester tester) async {
  await tester.tap(_button('Import Wallet'));
  await tester.pumpAndSettle();
}

Future<void> _typePhrase(WidgetTester tester, String phrase) async {
  await tester.enterText(find.byType(EditableText), phrase);
  await tester.pump();
}

const _colors = AppColorsV3.dark();

/// What the phrase field holds.
String _phrase(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).controller.text;

/// The colour the word count is drawn in.
Color? _countColor(WidgetTester tester) => tester
    .widget<Text>(find.descendant(of: find.byKey(ImportWalletPage.wordCountKey), matching: find.byType(Text)))
    .style
    ?.color;

/// Makes the system clipboard hold [text], or no text when it is null.
void _clipboardHolds(WidgetTester tester, String? text) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return text == null ? null : {'text': text};
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

/// How visible the Wallet Created page's terminal line [index] is.
double _lineOpacity(WidgetTester tester, int index) =>
    tester.widget<Opacity>(find.byKey(WalletCreatedPage.lineKey(index))).opacity;

/// Creates a wallet from Welcome and pumps until Wallet Created is up,
/// without waiting for anything to settle.
Future<void> _createWallet(WidgetTester tester) async {
  await tester.tap(_button('Create New Wallet'));
  for (var i = 0; i < 10 && find.byType(WalletCreatedPage).evaluate().isEmpty; i++) {
    await tester.pump();
  }
  expect(find.byType(WalletCreatedPage), findsOneWidget);
}

void main() {
  group('at start', () {
    testOnMac('with no wallet the window shows Welcome, not the sidebar or the account header', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);
      expect(find.byType(ShellTopBar), findsNothing);
    });

    testOnMac('with a wallet the window shows the shell, not Welcome', (tester) async {
      final device = FakeWalletDevice()..store([_root, _encrypted]);
      await pumpShell(tester, overrides: device.overrides);

      expect(find.byType(Sidebar), findsOneWidget);
      expect(_selectedRow('Account 1'), findsOneWidget);
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

    group('a wallet whose recovery phrase cannot be read', () {
      const notice = 'Unable to read your recovery phrase from this device.';
      const confirmTitle = 'Remove all wallets from this device?';

      // Behind the notice a spinner turns, which never settles.
      Future<void> settle(WidgetTester tester) async {
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<FakeWalletDevice> pumpWithoutPhrase(WidgetTester tester, {List<Object> exits = const []}) async {
        final device = FakeWalletDevice()..store([_root, _encrypted], mnemonic: null);
        await pumpShell(
          tester,
          overrides: [...device.overrides, forceAppExitProvider.overrideWithValue(() => exits.add('exit'))],
          settle: false,
        );
        await settle(tester);
        return device;
      }

      testOnMac('says so with Remove Wallet…, Quit and Try Again, and wipes nothing', (tester) async {
        final device = await pumpWithoutPhrase(tester);

        expect(find.text('Wallet Error'), findsOneWidget);
        expect(find.text(notice), findsOneWidget);
        expect(_button('Remove Wallet…'), findsOneWidget);
        expect(_button('Quit'), findsOneWidget);
        expect(_button('Try Again'), findsOneWidget);
        expect(_button('OK'), findsNothing);
        expect(find.byType(Sidebar), findsNothing);
        expect(device.logouts, 0);
      });

      testOnMac('Try Again with the phrase readable again opens the wallet and wipes nothing', (tester) async {
        final device = await pumpWithoutPhrase(tester);
        device.storage.mnemonics[0] = _twelveWords;

        await tester.tap(_button('Try Again'));
        await settle(tester);

        expect(find.text(notice), findsNothing);
        expect(_inSidebar('Account 1'), findsOneWidget);
        expect(device.logouts, 0);
      });

      testOnMac('Try Again with the phrase still missing says so again and wipes nothing', (tester) async {
        final device = await pumpWithoutPhrase(tester);
        final reads = device.storage.mnemonicReads;

        await tester.tap(_button('Try Again'));
        await settle(tester);

        expect(device.storage.mnemonicReads, greaterThan(reads));
        expect(find.text(notice), findsOneWidget);
        expect(find.byType(Sidebar), findsNothing);
        expect(device.logouts, 0);
      });

      testOnMac('Quit quits the app and wipes nothing', (tester) async {
        final exits = <Object>[];
        final device = await pumpWithoutPhrase(tester, exits: exits);

        await tester.tap(_button('Quit'));
        await settle(tester);

        expect(exits, ['exit']);
        expect(device.logouts, 0);
      });

      testOnMac('Remove Wallet… asks first, and Cancel goes back to the notice, wiping nothing', (tester) async {
        final device = await pumpWithoutPhrase(tester);

        await tester.tap(_button('Remove Wallet…'));
        await settle(tester);

        expect(find.text(confirmTitle), findsOneWidget);
        expect(find.text('This cannot be undone.'), findsOneWidget);
        await tester.tap(_button('Cancel'));
        await settle(tester);

        expect(find.text(confirmTitle), findsNothing);
        expect(find.text(notice), findsOneWidget);
        expect(device.logouts, 0);
      });

      testOnMac('Remove, once confirmed, wipes the wallet once and shows Welcome', (tester) async {
        final device = await pumpWithoutPhrase(tester);

        await tester.tap(_button('Remove Wallet…'));
        await settle(tester);
        await tester.tap(_button('Remove'));
        await settle(tester);

        expect(device.logouts, 1);
        expect(find.text('Wallet Error'), findsNothing);
        expect(find.byType(WelcomePage), findsOneWidget);
      });

      testOnMac('Escape and a click outside leave the notice open and wipe nothing', (tester) async {
        final device = await pumpWithoutPhrase(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle(tester);
        await tester.tapAt(const Offset(10, 790));
        await settle(tester);

        expect(find.text(notice), findsOneWidget);
        expect(device.logouts, 0);
      });
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
    testOnMac('shows the small line, the headline and the sentence, in place of the old tagline', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      expect(find.text('QUANTUM-SECURE ENCRYPTED MONEY'), findsOneWidget);
      expect(find.bySemanticsLabel('Quantum-Secure Encrypted Money'), findsOneWidget);
      expect(find.text('Money quantum\ncomputers can\u2019t break.'), findsOneWidget);
      expect(find.text('Create a new wallet, or import one you already have.'), findsOneWidget);
      expect(find.text('Quantum Secure Encrypted Money'), findsNothing);
      expect(_isEnabled(tester, 'Create New Wallet'), isTrue);
      expect(_isEnabled(tester, 'Import Wallet'), isTrue);

      // Top to bottom: the line, the headline, the sentence, the buttons.
      final tops = [
        find.text('QUANTUM-SECURE ENCRYPTED MONEY'),
        find.text('Money quantum\ncomputers can\u2019t break.'),
        find.text('Create a new wallet, or import one you already have.'),
        _button('Create New Wallet'),
      ].map((finder) => tester.getTopLeft(finder).dy).toList();
      expect(tops, orderedEquals([...tops]..sort()));
    });

    testOnMac('the logo sits in the top strip, clear of the traffic lights', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      final logo = tester.getRect(find.image(const AssetImage('assets/quantus_orange_logo.png')));
      expect(logo.left, greaterThanOrEqualTo(trafficLightsInset));
      expect(logo.center.dy, moreOrLessEquals(shellHeaderHeight / 2));
    });

    testOnWindowsAndLinux('the logo starts at the window\'s edge, where there are no traffic lights', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      expect(
        tester.getRect(find.image(const AssetImage('assets/quantus_orange_logo.png'))).left,
        lessThan(trafficLightsInset),
      );
    });

    testOnMac('the two buttons sit side by side, the same size, centred as a pair', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      final create = tester.getRect(_button('Create New Wallet'));
      final import = tester.getRect(_button('Import Wallet'));
      expect(create.size, import.size);
      expect(create.top, import.top);
      expect(create.right, lessThan(import.left));
      expect((create.left + import.right) / 2, moreOrLessEquals(600));
    });

    testOnMac('the buttons keep their size while a wallet is being created', (tester) async {
      final generated = Completer<String>();
      final device = FakeWalletDevice()..generateMnemonic = () => generated.future;
      await pumpShell(tester, overrides: device.overrides);
      final before = [
        tester.getRect(find.byType(QuantusButton).first),
        tester.getRect(find.byType(QuantusButton).last),
      ];

      await tester.tap(_button('Create New Wallet'));
      await tester.pump();

      expect([
        tester.getRect(find.byType(QuantusButton).first),
        tester.getRect(find.byType(QuantusButton).last),
      ], before);

      generated.complete(_twelveWords);
      await tester.pumpAndSettle();
    });

    test('the Welcome text is translated to Indonesian', () {
      final l10n = lookupAppLocalizations(const Locale('id'));

      expect(l10n.desktopWelcomeEyebrow, 'Uang Terenkripsi Aman Secara Kuantum');
      expect(l10n.desktopWelcomeTitleLine1, 'Uang yang tidak bisa');
      expect(l10n.desktopWelcomeTitleLine2, 'dipecahkan oleh komputer kuantum.');
      expect(l10n.desktopWelcomeBody, 'Buat dompet baru, atau impor dompet yang sudah Anda miliki.');
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
      expect(find.bySemanticsLabel('Wallet Created [OK]'), findsOneWidget);
      expect(find.bySemanticsLabel('Account 1 [OK]'), findsOneWidget);
      expect(find.bySemanticsLabel('Encrypted Account [OK]'), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);

      await tester.tap(_button('Go to Wallet'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletCreatedPage), findsNothing);
      expect(_selectedRow('Account 1'), findsOneWidget);
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
    testOnMac('the words are on the left, drawn as the design has them, and the field on the right', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _openImport(tester);

      expect(tester.widget<CapsText>(find.byType(CapsText).first).text, 'Import Wallet');
      expect(find.text('IMPORT WALLET'), findsOneWidget);
      expect(find.text('Restore your wallet.'), findsOneWidget);
      expect(find.text('12 OR 24 WORDS'), findsOneWidget);
      expect(find.text('SEPARATED BY SPACES'), findsOneWidget);
      expect(find.text('PASTE THE WHOLE PHRASE AT ONCE'), findsOneWidget);
      expect(find.text('RECOVERY PHRASE'), findsOneWidget);

      final field = tester.getRect(find.byType(QuantusSeedPhraseField));
      expect(tester.getRect(find.text('Restore your wallet.')).right, lessThan(field.left));
      expect(tester.getRect(find.text('PASTE THE WHOLE PHRASE AT ONCE')).right, lessThan(field.left));
      expect(tester.getRect(_button('Import Wallet')).right, moreOrLessEquals(field.right));
    });

    testOnMac('the word count follows what is typed', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _openImport(tester);

      expect(find.text('0 WORDS'), findsOneWidget);

      await _typePhrase(tester, 'abandon');
      expect(find.text('1 WORD'), findsOneWidget);

      await _typePhrase(tester, '  abandon   ability ');
      expect(find.text('2 WORDS'), findsOneWidget);

      await _typePhrase(tester, _twelveWords);
      expect(find.text('12 WORDS'), findsOneWidget);
    });

    testOnMac('the count turns sage at 12 and at 24 words, and is muted otherwise', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _openImport(tester);
      final eleven = _twelveWords.substring(0, _twelveWords.lastIndexOf(' '));

      await _typePhrase(tester, eleven);
      expect(_countColor(tester), _colors.textMuted2);

      await _typePhrase(tester, _twelveWords);
      expect(_countColor(tester), _colors.semanticSage);

      await _typePhrase(tester, '$_twelveWords abandon');
      expect(_countColor(tester), _colors.textMuted2);

      await _typePhrase(tester, '$_twelveWords $_twelveWords');
      expect(_countColor(tester), _colors.semanticSage);
    });

    testOnMac("Paste puts the clipboard's text in the field, in place of what was there", (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _openImport(tester);
      await _typePhrase(tester, 'abandon');
      _clipboardHolds(tester, _twelveWords);

      await tester.tap(find.widgetWithText(ToolbarAction, 'Paste'));
      await tester.pump();

      expect(_phrase(tester), _twelveWords);
      expect(find.text('12 WORDS'), findsOneWidget);
      expect(_isEnabled(tester, 'Import Wallet'), isTrue);
    });

    testOnMac('Paste with no text on the clipboard leaves the field as it is', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _openImport(tester);
      await _typePhrase(tester, 'abandon');
      _clipboardHolds(tester, null);

      await tester.tap(find.widgetWithText(ToolbarAction, 'Paste'));
      await tester.pump();

      expect(_phrase(tester), 'abandon');
      expect(find.text('1 WORD'), findsOneWidget);
    });

    testOnMac('opens from Welcome, with Import disabled until a phrase is typed', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      await _openImport(tester);

      expect(find.byType(ImportWalletPage), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
      expect(find.text('Restore an existing wallet with your 12 or 24 words recovery phrase'), findsOneWidget);
      expect(_isEnabled(tester, 'Import Wallet'), isFalse);

      await _typePhrase(tester, 'abandon');

      expect(_isEnabled(tester, 'Import Wallet'), isTrue);
    });

    testOnMac('its phrase field does not take the focus on opening', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);

      await _openImport(tester);

      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isFalse);
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

    testOnWindowsAndLinux('Esc returns to Welcome under the menu bar in the window too', (tester) async {
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
      await tester.tap(_button('Import Wallet'));
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
      await tester.tap(_button('Import Wallet'));
      await tester.pump();

      expect(_busyButton, findsOneWidget);
      expect(find.text('Import Wallet'), findsNothing);
      expect(find.byType(Sidebar), findsNothing);

      scanned.complete([]);
      await tester.pumpAndSettle();

      expect(device.storage.mnemonics, {0: _twelveWords});
      expect(find.byType(ImportWalletPage), findsNothing);
      expect(_selectedRow('Account 1'), findsOneWidget);
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
      await tester.tap(_button('Import Wallet'));
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
      await tester.tap(_button('Import Wallet'));
      await _pumpWhileBusy(tester);

      expect(find.text('Account scan failed'), findsOneWidget);
      expect(find.byType(Sidebar), findsNothing);

      await tester.tap(_button('Try again'));
      await tester.pumpAndSettle();

      expect(device.scans, 2);
      expect(find.text('Account scan failed'), findsNothing);
      expect(device.storage.pendingScans, isEmpty);
      expect(_selectedRow('Account 1'), findsOneWidget);
    });

    testOnMac('Skip after a failed account scan opens the wallet and leaves the scan for the next start', (
      tester,
    ) async {
      final device = FakeWalletDevice()..scan = () async => throw StateError('offline');
      await pumpShell(tester, overrides: device.overrides);
      await _openImport(tester);

      await _typePhrase(tester, _twelveWords);
      await tester.tap(_button('Import Wallet'));
      await _pumpWhileBusy(tester);
      await tester.tap(_button('Skip'));
      await tester.pumpAndSettle();

      expect(device.scans, 1);
      expect(device.storage.pendingScans, {0: 'qz(abandon)'});
      expect(_selectedRow('Account 1'), findsOneWidget);
    });

    testOnMac('any other failure is shown where the phrase was typed', (tester) async {
      final device = FakeWalletDevice()..storage.mnemonicWriteError = StateError('keychain is locked');
      await pumpShell(tester, overrides: device.overrides);
      await _openImport(tester);

      await _typePhrase(tester, _twelveWords);
      await tester.tap(_button('Import Wallet'));
      await tester.pumpAndSettle();

      expect(find.text('Bad state: keychain is locked'), findsOneWidget);
      expect(find.byType(ImportWalletPage), findsOneWidget);
      expect(_busyButton, findsNothing);
    });
  });

  group('Wallet Created', () {
    testOnMac('names each account in a line, and says what each kind of account is for', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _createWallet(tester);

      expect(find.textContaining('> WALLET CREATED'), findsOneWidget);
      expect(find.textContaining('> ACCOUNT 1'), findsOneWidget);
      expect(find.textContaining('> ENCRYPTED ACCOUNT'), findsOneWidget);
      expect(find.text('[OK]'), findsNWidgets(3));
      expect(find.text('Your wallet is ready.'), findsOneWidget);
      expect(
        find.text(
          'Account 1 is transparent: fast, and visible on chain. '
          'The Encrypted Account is for private transactions, and slower.',
        ),
        findsOneWidget,
      );
    });

    testOnMac('the logo sits in the top strip, clear of the traffic lights', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _createWallet(tester);

      final logo = tester.getRect(find.image(const AssetImage('assets/quantus_orange_logo.png')));
      expect(logo.left, greaterThanOrEqualTo(trafficLightsInset));
      expect(logo.center.dy, moreOrLessEquals(shellHeaderHeight / 2));
    });

    testOnMac('the lines appear one by one, all of them within 400 ms', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides, settle: false, reduceMotion: false);
      await _createWallet(tester);

      expect([for (var i = 0; i < 3; i++) _lineOpacity(tester, i)], [1, 0, 0]);

      await tester.pump(const Duration(milliseconds: 130));
      expect([for (var i = 0; i < 3; i++) _lineOpacity(tester, i)], [1, 1, 0]);

      await tester.pump(const Duration(milliseconds: 270));
      expect([for (var i = 0; i < 3; i++) _lineOpacity(tester, i)], [1, 1, 1]);
    });

    testOnMac('Go to Wallet works before the lines have appeared', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides, settle: false, reduceMotion: false);
      await _createWallet(tester);
      expect(_lineOpacity(tester, 2), 0);

      await tester.tap(_button('Go to Wallet'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletCreatedPage), findsNothing);
      expect(_selectedRow('Account 1'), findsOneWidget);
    });

    testOnMac('with reduced motion every line is there at once', (tester) async {
      await pumpShell(tester, overrides: FakeWalletDevice().overrides);
      await _createWallet(tester);

      expect([for (var i = 0; i < 3; i++) _lineOpacity(tester, i)], [1, 1, 1]);
    });

    test('the Import Wallet and Wallet Created text is translated to Indonesian', () {
      final l10n = lookupAppLocalizations(const Locale('id'));

      expect(l10n.desktopImportHeadline, 'Pulihkan dompet Anda.');
      expect(l10n.desktopImportPaste, 'Tempel');
      expect(l10n.desktopImportWordCount(12), '12 kata');
      expect(l10n.desktopWalletReadyHeadline, 'Dompet Anda siap.');
      expect(
        l10n.desktopWalletReadyBody('Akun 1', 'Akun Terenkripsi'),
        'Akun 1 bersifat transparan: cepat, dan terlihat di chain. Akun Terenkripsi untuk transaksi privat, '
        'dan lebih lambat.',
      );
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
