import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/services/background_mode.dart';
import 'package:quantus_desktop_wallet/services/background_window.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_info_sheet.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/app_locale.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../fakes.dart';
import 'fake_background_window.dart';
import 'fake_notification_plugin.dart';

const BackgroundModeRequest _keepsRunning = (
  keepRunning: true,
  openLabel: 'Open Quantus Wallet',
  quitLabel: 'Quit Quantus Wallet',
);
const BackgroundModeRequest _quits = (
  keepRunning: false,
  openLabel: 'Open Quantus Wallet',
  quitLabel: 'Quit Quantus Wallet',
);

/// A stored phrase whose words say where they are: `w01` … `w24`.
final _words = [for (var i = 1; i <= 24; i++) 'w${i.toString().padLeft(2, '0')}'];

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

typedef _Opened = ({FakeBackgroundWindow window, ProviderContainer container, List<String> exits});

/// The app, on a wallet of Main and Savings unless [hasWallet] is false.
Future<_Opened> _open(
  WidgetTester tester, {
  bool hasWallet = true,
  String locale = 'en',
  FakeUserApproval? approval,
  FakeNotificationPlugin? notifications,
}) async {
  final device = FakeWalletDevice();
  if (hasWallet) device.store(const [mainAccount, savingsAccount], mnemonic: _words.join(' '));
  device.storage.locale = locale;
  final window = FakeBackgroundWindow();
  final exits = <String>[];
  await pumpShell(
    tester,
    backgroundWindow: window,
    notifications: notifications,
    overrides: [
      ...device.overrides,
      systemApprovalProvider.overrideWithValue(approval ?? FakeUserApproval()),
      requestAppExitProvider.overrideWithValue(() => exits.add('exit')),
    ],
  );
  final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
  return (window: window, container: container, exits: exits);
}

/// File › Close Window.
Future<void> _closeFromMenu(WidgetTester tester, ProviderContainer container) async {
  final closing = container.read(backgroundModeProvider).closeWindow();
  await tester.pump();
  await closing;
  await tester.pumpAndSettle();
}

/// The window's close button.
Future<void> _pressClose(WidgetTester tester, FakeBackgroundWindow window) async {
  final closing = window.pressCloseButton();
  await tester.pump();
  await closing;
  await tester.pumpAndSettle();
}

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Opens Settings and shows the recovery phrase's words.
Future<void> _revealInSettings(WidgetTester tester, ProviderContainer container) async {
  container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
  await tester.pumpAndSettle();
  await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
  await _tap(tester, find.byKey(SettingsSheet.continueKey));
  await _tap(tester, find.byKey(SettingsSheet.hideKey));
  expect(_inSheet(find.text('w01')), findsOneWidget);
}

void main() {
  group('telling the window', () {
    testOnMac('with a wallet it keeps running, its menu in the app language', (tester) async {
      final (:window, container: _, exits: _) = await _open(tester);

      expect(window.configured.last, _keepsRunning);
    });

    testOnMac('the menu follows the language the app starts in', (tester) async {
      final (:window, container: _, exits: _) = await _open(tester, locale: 'id');

      expect(window.configured.last, (
        keepRunning: true,
        openLabel: 'Buka Quantus Wallet',
        quitLabel: 'Keluar dari Quantus Wallet',
      ));
    });

    testOnMac('with no wallet it quits on close', (tester) async {
      final (:window, container: _, exits: _) = await _open(tester, hasWallet: false);

      expect(window.configured.last, _quits);
    });

    testOnMac('a wallet being added tells it at once', (tester) async {
      final (:window, :container, exits: _) = await _open(tester, hasWallet: false);

      container.read(walletPresenceProvider.notifier).walletAdded();
      await tester.pump();

      expect(window.configured.last, _keepsRunning);
    });

    testOnMac('turning the setting off and on tells it at once', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      await container.read(keepRunningProvider.notifier).setEnabled(false);
      await tester.pump();
      expect(window.configured.last, _quits);

      await container.read(keepRunningProvider.notifier).setEnabled(true);
      await tester.pump();
      expect(window.configured.last, _keepsRunning);
    });

    testOnMac('a change of language updates its menu', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      await container.read(selectedAppLocaleProvider.notifier).select(AppLocale.fromCode('id'));
      await tester.pumpAndSettle();

      expect(window.configured.last.openLabel, 'Buka Quantus Wallet');
    });

    testOnWindowsAndLinux('Windows and Linux are asked nothing', (tester) async {
      final (:window, container: _, exits: _) = await _open(tester);

      expect(window.configured, isEmpty);
    });

    test('a request the window fails is reported', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final telemetry = _RecordingTelemetry();
      final window = FakeBackgroundWindow()..configureError = StateError('the window refused');
      final container = ProviderContainer(
        overrides: [
          ...shellOverrides(accounts: const [mainAccount]),
          backgroundWindowProvider.overrideWithValue(window),
          telemetryProvider.overrideWithValue(telemetry),
        ],
      );
      addTearDown(container.dispose);

      container.read(backgroundModeProvider);
      await Future<void>.delayed(Duration.zero);

      expect(telemetry.errors, contains('desktop_background_mode_failed'));
    });
  });

  group('Close Window', () {
    testOnMac('hides the window and leaves the app running', (tester) async {
      final (:window, :container, :exits) = await _open(tester);

      await _closeFromMenu(tester, container);

      expect(window.calls, ['hide']);
      expect(exits, isEmpty);
      expect(container.read(windowClosedProvider), isTrue);
    });

    testOnMac('with the setting off it quits', (tester) async {
      final (:window, :container, :exits) = await _open(tester);
      await container.read(keepRunningProvider.notifier).setEnabled(false);
      await tester.pump();

      await _closeFromMenu(tester, container);

      expect(exits, ['exit']);
      expect(window.calls, isEmpty);
    });

    testOnMac('with no wallet it quits', (tester) async {
      final (:window, :container, :exits) = await _open(tester, hasWallet: false);

      await _closeFromMenu(tester, container);

      expect(exits, ['exit']);
      expect(window.calls, isEmpty);
    });

    testWidgets('a window that fails to hide counts as open, and it is reported', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final telemetry = _RecordingTelemetry();
      final window = FakeBackgroundWindow()..hideError = StateError('the window refused');
      final container = ProviderContainer(
        overrides: [
          ...shellOverrides(accounts: const [mainAccount]),
          backgroundWindowProvider.overrideWithValue(window),
          telemetryProvider.overrideWithValue(telemetry),
        ],
      );
      addTearDown(container.dispose);
      container.read(backgroundModeProvider);
      await container.read(walletPresenceProvider.future);
      await tester.pump();

      await _closeFromMenu(tester, container);

      expect(container.read(windowClosedProvider), isFalse);
      expect(telemetry.errors, contains('desktop_background_mode_failed'));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('while closed', () {
    testOnMac('coming back through the Dock or the menu bar counts as open', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);
      await _pressClose(tester, window);
      expect(container.read(windowClosedProvider), isTrue);

      window.reopen();

      expect(container.read(windowClosedProvider), isFalse);
    });

    testOnMac('a menu command that opens a sheet brings the window forward', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);
      await _pressClose(tester, window);

      container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();

      expect(window.calls, ['bringToFront']);
      expect(container.read(windowClosedProvider), isFalse);
    });

    testOnMac('with the window open, a sheet asks nothing of it', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();

      expect(window.calls, isEmpty);
    });

    testOnMac('a notification click brings the window forward, on its account', (tester) async {
      final requests = recordWindowRequests(tester);
      final notifications = FakeNotificationPlugin();
      final (:window, :container, exits: _) = await _open(tester, notifications: notifications);
      await _pressClose(tester, window);

      notifications.click(jsonEncode({'accountId': savingsAccount.accountId}));
      await tester.pumpAndSettle();

      expect(requests, contains('bringToFront'));
      expect(container.read(activeAccountProvider).value?.account.accountId, savingsAccount.accountId);
    });
  });

  group('a recovery phrase', () {
    for (final (how, close) in <(String, Future<void> Function(WidgetTester, _Opened))>[
      ('Close Window', (tester, opened) => _closeFromMenu(tester, opened.container)),
      ('the close button', (tester, opened) => _pressClose(tester, opened.window)),
    ]) {
      testOnMac('on screen in Settings leaves it with $how, and needs approval again', (tester) async {
        final approval = FakeUserApproval();
        final opened = await _open(tester, approval: approval);
        await _revealInSettings(tester, opened.container);
        expect(approval.reasons, hasLength(1));

        await close(tester, opened);

        expect(_inSheet(find.text('w01')), findsNothing);
        expect(find.byKey(SettingsSheet.phraseGridKey), findsNothing);
        expect(find.byKey(SettingsSheet.recoveryPhraseRowKey), findsOneWidget);

        opened.window.reopen();
        await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
        await _tap(tester, find.byKey(SettingsSheet.continueKey));

        expect(approval.reasons, hasLength(2));
      });
    }

    testOnMac('on screen in Account Info leaves it, and needs approval again', (tester) async {
      final approval = FakeUserApproval();
      final opened = await _open(tester, approval: approval);
      await opened.container.read(accountManagerProvider).openInfo(mainAccount);
      await tester.pumpAndSettle();
      await _tap(tester, _inSheet(find.byKey(AccountInfoSheet.recoveryPhraseRowKey)));
      await _tap(tester, find.byKey(SettingsSheet.continueKey));
      await _tap(tester, find.byKey(SettingsSheet.hideKey));
      expect(_inSheet(find.text('w01')), findsOneWidget);

      await _pressClose(tester, opened.window);

      expect(_inSheet(find.text('w01')), findsNothing);
      expect(find.byKey(SettingsSheet.phraseGridKey), findsNothing);
      expect(find.byKey(AccountInfoSheet.recoveryPhraseRowKey), findsOneWidget);

      opened.window.reopen();
      await _tap(tester, _inSheet(find.byKey(AccountInfoSheet.recoveryPhraseRowKey)));
      await _tap(tester, find.byKey(SettingsSheet.continueKey));

      expect(approval.reasons, hasLength(2));
    });

    testOnMac('approved only after the window closed is not shown', (tester) async {
      final answer = Completer<ApprovalResult>();
      final approval = FakeUserApproval()..answer = () => answer.future;
      final opened = await _open(tester, approval: approval);
      opened.container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
      await tester.tap(find.byKey(SettingsSheet.continueKey));
      await tester.pump();

      await _pressClose(tester, opened.window);
      answer.complete(ApprovalResult.approved);
      await tester.pumpAndSettle();

      expect(find.byKey(SettingsSheet.phraseGridKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testOnMac('copied is still cleared from the clipboard on time with the window closed', (tester) async {
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SensitiveClipboard.channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SensitiveClipboard.channel, null));
      final (:window, :container, exits: _) = await _open(tester);

      await container.read(sensitiveClipboardProvider).copy('a copied phrase');
      await _pressClose(tester, window);
      await tester.pump(SensitiveClipboard.lifetime);

      expect(calls, ['copy', 'clear']);
    });
  });

  group('the native side', () {
    late List<MethodCall> sent;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sent = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(WindowChrome.channel, (
        call,
      ) async {
        sent.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        WindowChrome.channel,
        null,
      );
      WindowChrome.channel.setMethodCallHandler(null);
    });

    Future<void> fromNative(String method) async {
      final answered = Completer<void>();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        WindowChrome.channel.name,
        WindowChrome.channel.codec.encodeMethodCall(MethodCall(method)),
        (_) => answered.complete(),
      );
      await answered.future;
    }

    test('is told the mode, with its labels', () async {
      await const BackgroundWindow().configure(_keepsRunning);

      expect(sent.single.method, 'setBackgroundMode');
      expect(sent.single.arguments, {
        'keepRunning': true,
        'openLabel': 'Open Quantus Wallet',
        'quitLabel': 'Quit Quantus Wallet',
      });
    });

    test('is asked to hide', () async {
      await const BackgroundWindow().hide();

      expect(sent.single.method, 'hideWindow');
    });

    test('is answered only once the app is ready for the window to close', () async {
      final ready = Completer<void>();
      var opened = 0;
      const BackgroundWindow().listen(onWillClose: () => ready.future, onDidOpen: () => opened++);
      var answered = false;
      unawaited(fromNative('windowWillClose').then((_) => answered = true));
      await Future<void>.delayed(Duration.zero);
      expect(answered, isFalse);

      ready.complete();
      await Future<void>.delayed(Duration.zero);
      expect(answered, isTrue);

      await fromNative('windowDidOpen');
      expect(opened, 1);
    });
  });
}
