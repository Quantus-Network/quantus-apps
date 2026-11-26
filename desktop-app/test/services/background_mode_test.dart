import 'dart:async';
import 'dart:convert';
import 'dart:ui' show AppExitResponse;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/status_item_swaps.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/services/background_mode.dart';
import 'package:quantus_desktop_wallet/services/background_window.dart';
import 'package:quantus_desktop_wallet/services/own_activity_notifications.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_info_sheet.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/app_locale.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../fakes.dart';
import 'fake_background_window.dart';
import 'fake_notification_plugin.dart';

const StatusItemLabels _labels = (openLabel: 'Open Quantus Wallet', quitLabel: 'Quit Quantus Wallet');

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

/// The app, on a wallet of Main and Savings unless [hasWallet] is false. With
/// [workUnderWay] something is under way, so closing the window hides it.
Future<_Opened> _open(
  WidgetTester tester, {
  bool hasWallet = true,
  bool workUnderWay = false,
  String locale = 'en',
  FakeUserApproval? approval,
  FakeNotificationPlugin? notifications,
  bool realLogout = false,
  FakeWalletDevice? onDevice,
}) async {
  final device = (onDevice ?? FakeWalletDevice())..realLogout = realLogout;
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
      forceAppExitProvider.overrideWithValue(() => exits.add('forced')),
    ],
  );
  final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
  if (workUnderWay) container.read(workHoldsProvider.notifier).hold(_work);
  return (window: window, container: container, exits: exits);
}

/// What holds the app open in a test that has work under way.
const _work = 'work under way';

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

/// A wallet whose indexer holds Main's send, with a broadcast send under way.
Future<_Opened> _openOnASend(
  WidgetTester tester,
  FakeNotificationPlugin notifications, {
  FakeWalletDevice? device,
}) async {
  const sendHash = '0xsend';
  device ??= FakeWalletDevice();
  device.chain.indexedTransfers[sendHash] = TransferEvent(
    id: 'indexed-send',
    from: mainAccount.accountId,
    to: 'qzBob',
    amount: oneToken,
    timestamp: DateTime(2026),
    fee: BigInt.zero,
    extrinsicHash: sendHash,
    blockNumber: 10,
    blockHash: '0xblock',
  );
  final opened = await _open(tester, onDevice: device, notifications: notifications);
  final sends = opened.container.read(pendingTransactionsProvider.notifier);
  sends.add(
    PendingTransactionEvent(
      tempId: 'tx-1',
      from: mainAccount.accountId,
      to: 'qzBob',
      amount: oneToken,
      fee: BigInt.zero,
      timestamp: DateTime(2026),
    ),
  );
  sends.updateState('tx-1', TransactionState.pending, extrinsicHash: sendHash);
  await tester.pump();
  return opened;
}

/// What the wallet does once it has found the send of [_openOnASend].
void _confirmSend(ProviderContainer container) {
  final sends = container.read(pendingTransactionsProvider.notifier);
  sends.updateState('tx-1', TransactionState.inHistory);
  sends.remove('tx-1');
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
    testOnMac('the menu bar icon gets its labels in the app language', (tester) async {
      final (:window, container: _, exits: _) = await _open(tester);

      expect(window.configured.last, _labels);
    });

    testOnMac('the menu follows the language the app starts in', (tester) async {
      final (:window, container: _, exits: _) = await _open(tester, locale: 'id');

      expect(window.configured.last, (openLabel: 'Buka Quantus Wallet', quitLabel: 'Keluar dari Quantus Wallet'));
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
    testOnMac('with work under way, the menu item hides the window and leaves the app running', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);

      await _closeFromMenu(tester, container);

      expect(window.calls, ['hide']);
      expect(exits, isEmpty);
      expect(container.read(windowClosedProvider), isTrue);
    });

    testOnMac('with work under way, the close button hides the window and leaves the app running', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);

      await _pressClose(tester, window);

      expect(window.calls, ['hide']);
      expect(exits, isEmpty);
      expect(container.read(windowClosedProvider), isTrue);
    });

    testOnMac('with nothing under way, the menu item quits', (tester) async {
      final (:window, :container, :exits) = await _open(tester);

      await _closeFromMenu(tester, container);

      expect(exits, ['exit']);
      expect(window.calls, isEmpty);
      expect(container.read(windowClosedProvider), isFalse);
    });

    testOnMac('with nothing under way, the close button lets the window close, which quits', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      await _pressClose(tester, window);

      expect(window.calls, ['quit']);
      expect(container.read(windowClosedProvider), isFalse);
    });

    testOnMac('with no wallet it quits', (tester) async {
      final (:window, :container, :exits) = await _open(tester, hasWallet: false);

      await _closeFromMenu(tester, container);

      expect(exits, ['exit']);
      expect(window.calls, isEmpty);
    });

    testOnMac('work that started just before the close is honored', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      container.read(workHoldsProvider.notifier).hold(_work);
      await _pressClose(tester, window);

      expect(window.calls, ['hide']);
    });

    testOnWindowsAndLinux('Windows and Linux quit, even with work under way', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);

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
      container.read(workHoldsProvider.notifier).hold(_work);
      await tester.pump();

      await _closeFromMenu(tester, container);

      expect(container.read(windowClosedProvider), isFalse);
      expect(telemetry.errors, contains('desktop_background_mode_failed'));
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('while closed', () {
    testOnMac('coming back through the Dock or the menu bar counts as open', (tester) async {
      final (:window, :container, exits: _) = await _open(tester, workUnderWay: true);
      await _pressClose(tester, window);
      expect(container.read(windowClosedProvider), isTrue);

      window.reopen();

      expect(container.read(windowClosedProvider), isFalse);
    });

    testOnMac('closing a window already off the screen waits for no frame', (tester) async {
      final (:window, :container, exits: _) = await _open(tester, workUnderWay: true);
      addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      var finished = false;
      unawaited(window.pressCloseButton().then((_) => finished = true));
      await tester.idle();

      expect(finished, isTrue);
      expect(container.read(windowClosedProvider), isTrue);
    });

    testOnMac('a menu command that opens a sheet brings the window forward', (tester) async {
      final (:window, :container, exits: _) = await _open(tester, workUnderWay: true);
      await _pressClose(tester, window);

      container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();

      expect(window.calls, ['hide', 'bringToFront']);
      expect(container.read(windowClosedProvider), isFalse);
    });

    testOnMac('with the window open, a sheet asks nothing of it', (tester) async {
      final (:window, :container, exits: _) = await _open(tester, workUnderWay: true);

      container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
      await tester.pumpAndSettle();

      expect(window.calls, isEmpty);
    });

    testOnMac('a notification click brings the window forward, on its account', (tester) async {
      final requests = recordWindowRequests(tester);
      final notifications = FakeNotificationPlugin();
      final (:window, :container, exits: _) = await _open(tester, workUnderWay: true, notifications: notifications);
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
        final opened = await _open(tester, workUnderWay: true, approval: approval);
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
      final opened = await _open(tester, workUnderWay: true, approval: approval);
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
      final opened = await _open(tester, workUnderWay: true, approval: approval);
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

    for (final (sheet, openCaution, rowKey) in <(String, Future<void> Function(WidgetTester, _Opened), Key)>[
      (
        'Settings',
        (tester, opened) async {
          opened.container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
          await tester.pumpAndSettle();
          await _tap(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
        },
        SettingsSheet.recoveryPhraseRowKey,
      ),
      (
        'Account Info',
        (tester, opened) async {
          await opened.container.read(accountManagerProvider).openInfo(mainAccount);
          await tester.pumpAndSettle();
          await _tap(tester, _inSheet(find.byKey(AccountInfoSheet.recoveryPhraseRowKey)));
        },
        AccountInfoSheet.recoveryPhraseRowKey,
      ),
    ]) {
      /// Presses the close button, with [finish] answering before the frame
      /// that takes the caution away; then the window comes back, and the
      /// phrase needs a new approval, which still works.
      Future<void> expectNotRestored(
        WidgetTester tester,
        _Opened opened,
        FakeUserApproval approval,
        VoidCallback finish, {
        VoidCallback? whileClosed,
      }) async {
        final closing = opened.window.pressCloseButton();
        finish();
        await tester.idle();
        await tester.pump();
        await closing;
        await tester.pumpAndSettle();

        expect(find.byKey(SettingsSheet.phraseGridKey), findsNothing);
        whileClosed?.call();

        opened.window.reopen();
        await tester.pumpAndSettle();

        expect(find.byKey(SettingsSheet.phraseGridKey), findsNothing);
        expect(approval.reasons, hasLength(1));

        approval.answer = () async => ApprovalResult.approved;
        await _tap(tester, _inSheet(find.byKey(rowKey)));
        await _tap(tester, find.byKey(SettingsSheet.continueKey));

        expect(approval.reasons, hasLength(2));
        expect(find.byKey(SettingsSheet.phraseGridKey), findsOneWidget);
      }

      testOnMac('in $sheet, an approval answering before the closing frame is dropped, the phrase unread', (
        tester,
      ) async {
        final answer = Completer<ApprovalResult>();
        final approval = FakeUserApproval()..answer = () => answer.future;
        final device = FakeWalletDevice();
        final opened = await _open(tester, workUnderWay: true, approval: approval, onDevice: device);
        await openCaution(tester, opened);
        await tester.tap(find.byKey(SettingsSheet.continueKey));
        await tester.pump();
        final readsBefore = device.storage.mnemonicReads;

        await expectNotRestored(
          tester,
          opened,
          approval,
          () => answer.complete(ApprovalResult.approved),
          whileClosed: () => expect(device.storage.mnemonicReads, readsBefore),
        );
      });

      testOnMac('in $sheet, a phrase read finishing before the closing frame is dropped', (tester) async {
        final read = Completer<void>();
        final approval = FakeUserApproval();
        final device = FakeWalletDevice();
        final opened = await _open(tester, workUnderWay: true, approval: approval, onDevice: device);
        // Held only from here: the app reads the phrase as it starts, too.
        device.storage.mnemonicGate = read.future;
        await openCaution(tester, opened);
        await tester.tap(find.byKey(SettingsSheet.continueKey));
        await tester.pump();
        expect(approval.reasons, hasLength(1));

        await expectNotRestored(tester, opened, approval, read.complete);
      });
    }

    testOnMac('copied is still cleared from the clipboard on time with the window closed', (tester) async {
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SensitiveClipboard.channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SensitiveClipboard.channel, null));
      final (:window, :container, exits: _) = await _open(tester, workUnderWay: true);

      await container.read(sensitiveClipboardProvider).copy('a copied phrase');
      await _pressClose(tester, window);
      await tester.pump(SensitiveClipboard.lifetime);

      expect(calls, ['copy', 'clear']);
    });
  });

  group('closed until the work settles', () {
    const proposalHash = '0xproposal';

    /// [_openOnASend], its window closed.
    Future<_Opened> closedOnASend(
      WidgetTester tester,
      FakeNotificationPlugin notifications, {
      FakeWalletDevice? device,
    }) async {
      final opened = await _openOnASend(tester, notifications, device: device);
      await _pressClose(tester, opened.window);
      return opened;
    }

    testOnMac('the last work settling quits the app, a moment later', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);
      await _pressClose(tester, window);

      container.read(workHoldsProvider.notifier).release(_work);
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay - const Duration(milliseconds: 1));
      expect(exits, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      expect(exits, ['exit']);
    });

    testOnMac('one of two settling leaves it running', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);
      final holds = container.read(workHoldsProvider.notifier)..hold('more work');
      await _pressClose(tester, window);

      holds.release(_work);
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay * 2);
      expect(exits, isEmpty);

      holds.release('more work');
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay);
      expect(exits, ['exit']);
    });

    testOnMac('work settling with the window open does not quit', (tester) async {
      final (window: _, :container, :exits) = await _open(tester, workUnderWay: true);

      container.read(workHoldsProvider.notifier).release(_work);
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay * 2);

      expect(exits, isEmpty);
    });

    testOnMac('a send confirmed while closed has its notification handed over before the app quits', (tester) async {
      final notifications = FakeNotificationPlugin();
      final (window: _, :container, :exits) = await closedOnASend(tester, notifications);
      final handover = notifications.heldShow = Completer<void>();

      final sends = container.read(pendingTransactionsProvider.notifier);
      sends.updateState('tx-1', TransactionState.inHistory);
      sends.remove('tx-1');
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay * 2);
      expect(notifications.shown, hasLength(1));
      expect(exits, isEmpty);

      handover.complete();
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay);
      expect(exits, ['exit']);
    });

    testOnMac('work settling twice while a notification is handed over quits once', (tester) async {
      final notifications = FakeNotificationPlugin();
      final (window: _, :container, :exits) = await closedOnASend(tester, notifications);
      final handover = notifications.heldShow = Completer<void>();
      final sends = container.read(pendingTransactionsProvider.notifier);
      sends.updateState('tx-1', TransactionState.inHistory);
      sends.remove('tx-1');
      await tester.pump();
      await tester.pump();

      final holds = container.read(workHoldsProvider.notifier)..hold(_work);
      await tester.pump();
      holds.release(_work);
      await tester.pump();

      handover.complete();
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay);

      expect(exits, ['exit']);
    });

    testOnMac('a confirmed send whose amount is still being read keeps the app until it is notified', (tester) async {
      final notifications = FakeNotificationPlugin();
      final device = FakeWalletDevice();
      final (window: _, :container, :exits) = await closedOnASend(tester, notifications, device: device);
      final search = device.chain.holdHashSearch = Completer<void>();

      final sends = container.read(pendingTransactionsProvider.notifier);
      sends.updateState('tx-1', TransactionState.inHistory);
      sends.remove('tx-1');
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay * 2);
      expect(notifications.shown, isEmpty);
      expect(exits, isEmpty);

      search.complete();
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay);
      expect(notifications.shown, hasLength(1));
      expect(exits, ['exit']);
    });

    for (final outcome in [SendConfirmation.confirmed, SendConfirmation.unconfirmed]) {
      testOnMac('a proposal ${outcome.name} while closed has its notification handed over first', (tester) async {
        final notifications = FakeNotificationPlugin();
        final device = FakeWalletDevice();
        device.storage.multisigStore.add(teamMultisig);
        final (:window, :container, :exits) = await _open(tester, onDevice: device, notifications: notifications);
        final proposals = container.read(pendingMultisigProposalsProvider.notifier);
        proposals.add(
          PendingMultisigProposalEvent(
            tempId: 'proposal-1',
            multisigAddress: teamMultisig.accountId,
            proposerId: mainAccount.accountId,
            recipient: 'qzBob',
            amount: oneToken,
            deposit: BigInt.zero,
            expiryBlock: 100,
            palletFee: BigInt.zero,
          ),
        );
        proposals.update('proposal-1', extrinsicHash: proposalHash);
        await tester.pump();
        await _pressClose(tester, window);
        final handover = notifications.heldShow = Completer<void>();

        // In the wallet's own order: a created proposal leaves the list first.
        final confirmations = container.read(multisigProposalConfirmationsProvider.notifier);
        if (outcome == SendConfirmation.confirmed) {
          proposals.remove('proposal-1');
          confirmations.settle(proposalHash, outcome);
        } else {
          confirmations.settle(proposalHash, outcome);
          proposals.remove('proposal-1');
        }
        await tester.pump();
        await tester.pump(BackgroundMode.settleDelay * 2);
        expect(notifications.shown, hasLength(1));
        expect(exits, isEmpty);

        handover.complete();
        await tester.pump();
        await tester.pump(BackgroundMode.settleDelay);
        expect(exits, ['exit']);
      });
    }

    testOnMac('reopening before it settles cancels the quit, and the app stays open after', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);
      await _pressClose(tester, window);

      window.reopen();
      container.read(workHoldsProvider.notifier).release(_work);
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay * 2);

      expect(exits, isEmpty);
      expect(container.read(windowClosedProvider), isFalse);
    });

    testOnMac('reopening during the last moment cancels the quit', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);
      await _pressClose(tester, window);
      container.read(workHoldsProvider.notifier).release(_work);
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay ~/ 2);

      window.reopen();
      await tester.pump(BackgroundMode.settleDelay * 2);

      expect(exits, isEmpty);
    });

    testOnMac('new work during the last moment holds the quit until it settles too', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);
      final holds = container.read(workHoldsProvider.notifier);
      await _pressClose(tester, window);
      holds.release(_work);
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay ~/ 2);

      holds.hold('new work');
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay * 2);
      expect(exits, isEmpty);

      holds.release('new work');
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay);
      expect(exits, ['exit']);
    });

    testOnMac('work that comes and goes during the last moment starts that moment again', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);
      final holds = container.read(workHoldsProvider.notifier);
      await _pressClose(tester, window);
      holds.release(_work);
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay ~/ 2);

      holds.hold('brief work');
      await tester.pump();
      holds.release('brief work');
      await tester.pump();

      await tester.pump(BackgroundMode.settleDelay - const Duration(milliseconds: 1));
      expect(exits, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      expect(exits, ['exit']);
    });

    testOnMac('a notification handed over during the last moment gets its own', (tester) async {
      final notifications = FakeNotificationPlugin();
      final device = FakeWalletDevice();
      device.storage.multisigStore.add(teamMultisig);
      final (:window, :container, :exits) = await _open(tester, onDevice: device, notifications: notifications);
      final proposals = container.read(pendingMultisigProposalsProvider.notifier);
      proposals.add(
        PendingMultisigProposalEvent(
          tempId: 'proposal-1',
          multisigAddress: teamMultisig.accountId,
          proposerId: mainAccount.accountId,
          recipient: 'qzBob',
          amount: oneToken,
          deposit: BigInt.zero,
          expiryBlock: 100,
          palletFee: BigInt.zero,
        ),
      );
      proposals.update('proposal-1', extrinsicHash: proposalHash);
      await tester.pump();
      await _pressClose(tester, window);
      proposals.remove('proposal-1');
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay ~/ 2);

      container.read(multisigProposalConfirmationsProvider.notifier).settle(proposalHash, SendConfirmation.confirmed);
      await tester.pump();
      expect(notifications.shown, hasLength(1));

      await tester.pump(BackgroundMode.settleDelay - const Duration(milliseconds: 1));
      expect(exits, isEmpty);

      await tester.pump(BackgroundMode.settleDelay);
      expect(exits, ['exit']);
    });

    testWidgets('work still under way at the limit brings the window back, quits nothing, and is reported', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final telemetry = _RecordingTelemetry();
      final window = FakeBackgroundWindow();
      final exits = <String>[];
      final container = ProviderContainer(
        overrides: [
          ...shellOverrides(accounts: const [mainAccount]),
          backgroundWindowProvider.overrideWithValue(window),
          telemetryProvider.overrideWithValue(telemetry),
          requestAppExitProvider.overrideWithValue(() => exits.add('exit')),
        ],
      );
      addTearDown(container.dispose);
      container.read(backgroundModeProvider);
      container.read(workHoldsProvider.notifier).hold(_work);
      await tester.pump();
      await _pressClose(tester, window);

      await tester.pump(BackgroundMode.hiddenLimit - const Duration(seconds: 1));
      expect(window.calls, ['hide']);

      await tester.pump(const Duration(seconds: 1));

      expect(window.calls, ['hide', 'bringToFront']);
      expect(container.read(windowClosedProvider), isFalse);
      expect(exits, isEmpty);
      expect(telemetry.errors, contains('desktop_background_work_stuck'));
      debugDefaultTargetPlatformOverride = null;
    });

    testOnMac('a notification that never finishes handing over brings the window back at the limit', (tester) async {
      final notifications = FakeNotificationPlugin();
      final (:window, :container, :exits) = await closedOnASend(tester, notifications);
      notifications.heldShow = Completer<void>();
      final sends = container.read(pendingTransactionsProvider.notifier);
      sends.updateState('tx-1', TransactionState.inHistory);
      sends.remove('tx-1');
      await tester.pump();

      await tester.pump(BackgroundMode.hiddenLimit);

      expect(window.calls, ['hide', 'bringToFront']);
      expect(exits, isEmpty);
    });

    testOnMac('a window reopened before the limit is not brought forward again', (tester) async {
      final (:window, container: _, :exits) = await _open(tester, workUnderWay: true);
      await _pressClose(tester, window);

      window.reopen();
      await tester.pump(BackgroundMode.hiddenLimit);

      expect(window.calls, ['hide']);
      expect(exits, isEmpty);
    });
  });

  group('quitting', () {
    const title = 'A Transaction Is Still Under Way';
    const finishFirst = 'Finish, Then Quit';
    const quitNow = 'Quit Now';

    /// Cmd+Q or the menu bar icon's Quit, as the system passes it on.
    Future<AppExitResponse> requestQuit(WidgetTester tester) async {
      final response = await tester.binding.handleRequestAppExit();
      await tester.pumpAndSettle();
      return response;
    }

    testOnMac('with nothing under way it quits without asking', (tester) async {
      await _open(tester);

      expect(await requestQuit(tester), AppExitResponse.exit);
      expect(find.text(title), findsNothing);
    });

    testOnMac('with work under way it stays, and asks', (tester) async {
      final (:window, container: _, :exits) = await _open(tester, workUnderWay: true);

      expect(await requestQuit(tester), AppExitResponse.cancel);

      expect(find.text(title), findsOneWidget);
      expect(find.text(finishFirst), findsOneWidget);
      expect(find.text(quitNow), findsOneWidget);
      expect(window.calls, isEmpty);
      expect(exits, isEmpty);
    });

    testOnMac('from the menu bar icon, with the window closed, it brings the window forward to ask', (tester) async {
      final (:window, :container, exits: _) = await _open(tester, workUnderWay: true);
      await _pressClose(tester, window);

      expect(await requestQuit(tester), AppExitResponse.cancel);

      expect(window.calls, ['hide', 'bringToFront']);
      expect(container.read(windowClosedProvider), isFalse);
      expect(find.text(title), findsOneWidget);
    });

    testOnMac('Finish, Then Quit hides the window and quits once the work settles', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);
      await requestQuit(tester);

      await _tap(tester, find.text(finishFirst));

      expect(find.text(title), findsNothing);
      expect(window.calls, ['hide']);
      expect(container.read(windowClosedProvider), isTrue);
      expect(exits, isEmpty);

      container.read(workHoldsProvider.notifier).release(_work);
      await tester.pump();
      await tester.pump(BackgroundMode.settleDelay);
      expect(exits, ['exit']);
    });

    testOnMac('Finish, Then Quit quits at once if the work settled while it was asking', (tester) async {
      final (:window, :container, :exits) = await _open(tester, workUnderWay: true);
      await requestQuit(tester);
      container.read(workHoldsProvider.notifier).release(_work);
      await tester.pump();

      await _tap(tester, find.text(finishFirst));

      expect(exits, ['exit']);
      expect(window.calls, isEmpty);
    });

    testOnMac('Quit Now quits, whatever is under way', (tester) async {
      final (window: _, container: _, :exits) = await _open(tester, workUnderWay: true);
      await requestQuit(tester);

      await _tap(tester, find.text(quitNow));

      expect(exits, ['forced']);
    });

    testOnMac('a second quit while it asks neither skips the question nor asks twice', (tester) async {
      final (window: _, container: _, :exits) = await _open(tester, workUnderWay: true);
      await requestQuit(tester);

      expect(await requestQuit(tester), AppExitResponse.cancel);

      expect(find.text(title), findsOneWidget);
      expect(exits, isEmpty);
    });

    testOnMac('a second quit with the window closed behind the question brings it back, without a second one', (
      tester,
    ) async {
      final (:window, container: _, :exits) = await _open(tester, workUnderWay: true);
      await requestQuit(tester);
      await _pressClose(tester, window);
      expect(window.calls, ['hide']);

      expect(await requestQuit(tester), AppExitResponse.cancel);

      expect(window.calls, ['hide', 'bringToFront']);
      expect(find.text(title), findsOneWidget);
      expect(exits, isEmpty);
    });

    testOnMac('after answering, a later quit with work under way asks again', (tester) async {
      final (:window, container: _, exits: _) = await _open(tester, workUnderWay: true);
      await requestQuit(tester);
      await _tap(tester, find.text(finishFirst));
      window.reopen();
      await tester.pumpAndSettle();

      expect(await requestQuit(tester), AppExitResponse.cancel);

      expect(find.text(title), findsOneWidget);
    });

    for (final (stage, hold) in <(String, Completer<void> Function(FakeWalletDevice, FakeNotificationPlugin))>[
      ('being prepared', (device, _) => device.chain.holdHashSearch = Completer<void>()),
      ('being handed over', (_, notifications) => notifications.heldShow = Completer<void>()),
    ]) {
      group('with a confirmed send\'s notification $stage', () {
        Future<({_Opened opened, Completer<void> held})> confirmed(WidgetTester tester) async {
          final notifications = FakeNotificationPlugin();
          final device = FakeWalletDevice();
          final opened = await _openOnASend(tester, notifications, device: device);
          final held = hold(device, notifications);
          _confirmSend(opened.container);
          await tester.pump();
          return (opened: opened, held: held);
        }

        Future<void> expectQuitsOnceDelivered(WidgetTester tester, _Opened opened, Completer<void> held) async {
          expect(opened.window.calls, ['hide']);
          expect(opened.exits, isEmpty);
          await tester.pump(BackgroundMode.settleDelay * 2);
          expect(opened.exits, isEmpty);

          held.complete();
          await tester.pump();
          await tester.pump(BackgroundMode.settleDelay);
          expect(opened.exits, ['exit']);
        }

        testOnMac('File › Close Window hides, and quits once it is delivered', (tester) async {
          final (:opened, :held) = await confirmed(tester);

          await _closeFromMenu(tester, opened.container);

          await expectQuitsOnceDelivered(tester, opened, held);
        });

        testOnMac('the close button hides, and quits once it is delivered', (tester) async {
          final (:opened, :held) = await confirmed(tester);

          await _pressClose(tester, opened.window);

          await expectQuitsOnceDelivered(tester, opened, held);
        });

        testOnMac('Cmd+Q stays and asks', (tester) async {
          final (:opened, held: _) = await confirmed(tester);

          expect(await requestQuit(tester), AppExitResponse.cancel);

          expect(find.text(title), findsOneWidget);
          expect(opened.exits, isEmpty);
        });

        testOnMac('Quit Now still quits at once', (tester) async {
          final (:opened, held: _) = await confirmed(tester);
          await requestQuit(tester);

          await _tap(tester, find.text(quitNow));

          expect(opened.exits, ['forced']);
        });

        testOnMac('Finish, Then Quit, the send having confirmed while it asked, waits for it', (tester) async {
          final notifications = FakeNotificationPlugin();
          final device = FakeWalletDevice();
          final opened = await _openOnASend(tester, notifications, device: device);
          await requestQuit(tester);
          final held = hold(device, notifications);
          _confirmSend(opened.container);
          await tester.pump();

          await _tap(tester, find.text(finishFirst));

          await expectQuitsOnceDelivered(tester, opened, held);
        });
      });
    }

    group('just after a notification was handed over', () {
      Future<_Opened> delivered(WidgetTester tester) async {
        final opened = await _openOnASend(tester, FakeNotificationPlugin());
        _confirmSend(opened.container);
        await tester.pump();
        await tester.pump(BackgroundMode.settleDelay ~/ 2);
        return opened;
      }

      testOnMac('File › Close Window hides, and quits a moment later', (tester) async {
        final opened = await delivered(tester);

        await _closeFromMenu(tester, opened.container);

        expect(opened.window.calls, ['hide']);
        expect(opened.exits, isEmpty);
        await tester.pump(BackgroundMode.settleDelay);
        expect(opened.exits, ['exit']);
      });

      testOnMac('the close button hides, and quits a moment later', (tester) async {
        final opened = await delivered(tester);

        await _pressClose(tester, opened.window);

        expect(opened.window.calls, ['hide']);
        expect(opened.exits, isEmpty);
        await tester.pump(BackgroundMode.settleDelay);
        expect(opened.exits, ['exit']);
      });

      testOnMac('Cmd+Q stays and asks', (tester) async {
        await delivered(tester);

        expect(await requestQuit(tester), AppExitResponse.cancel);

        expect(find.text(title), findsOneWidget);
      });

      testOnMac('once the moment has passed, closing quits at once', (tester) async {
        final opened = await delivered(tester);
        await tester.pump(BackgroundMode.settleDelay);

        await _closeFromMenu(tester, opened.container);

        expect(opened.exits, ['exit']);
        expect(opened.window.calls, isEmpty);
      });
    });

    testOnWindowsAndLinux('Windows and Linux quit without asking', (tester) async {
      await _open(tester, workUnderWay: true);

      expect(await requestQuit(tester), AppExitResponse.exit);
      expect(find.text(title), findsNothing);
    });
  });

  group('an Encrypted send handed to the node', () {
    const hash = '0xencrypted';

    Future<_Opened> handedOver(
      WidgetTester tester,
      FakeNotificationPlugin notifications, {
      FakeWalletDevice? device,
      bool realLogout = false,
    }) async {
      final opened = await _open(tester, onDevice: device, notifications: notifications, realLogout: realLogout);
      opened.container
          .read(ownActivityNotificationsProvider)
          .onEncryptedSendEnded(
            account: mainAccount,
            amount: oneToken,
            send: EncryptedSendState(phase: EncryptedSendPhase.succeeded, txHashes: const [hash]),
          );
      await tester.pump();
      return opened;
    }

    testOnMac('closing waits for the chain and the Sent notification, then quits', (tester) async {
      final notifications = FakeNotificationPlugin();
      final device = FakeWalletDevice();
      final (:window, :container, :exits) = await handedOver(tester, notifications, device: device);

      await _pressClose(tester, window);
      await tester.pump(const Duration(seconds: 6));
      expect(container.read(windowClosedProvider), isTrue);
      expect(exits, isEmpty);

      device.chain.indexedTransfers[hash] = TransferEvent(
        id: 'indexed-encrypted',
        from: mainAccount.accountId,
        to: 'qzBob',
        amount: oneToken,
        timestamp: DateTime(2026),
        fee: BigInt.zero,
        extrinsicHash: hash,
        blockNumber: 10,
        blockHash: '0xblock',
      );
      // The next search, five seconds after the last.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(notifications.shown.single.title, startsWith('Sent'));
      expect(exits, isEmpty);

      await tester.pump(BackgroundMode.settleDelay * 2);
      expect(exits, ['exit']);
    });

    testOnMac('the app stays while the account reloads, before the notification', (tester) async {
      final notifications = FakeNotificationPlugin();
      final device = FakeWalletDevice();
      final (:window, container: _, :exits) = await handedOver(tester, notifications, device: device);
      await _pressClose(tester, window);
      final reload = device.holdEncryptedState = Completer<void>();
      device.chain.indexedTransfers[hash] = TransferEvent(
        id: 'indexed-encrypted',
        from: mainAccount.accountId,
        to: 'qzBob',
        amount: oneToken,
        timestamp: DateTime(2026),
        fee: BigInt.zero,
        extrinsicHash: hash,
        blockNumber: 10,
        blockHash: '0xblock',
      );

      await tester.pump(const Duration(seconds: 6));
      await tester.pump(BackgroundMode.settleDelay * 2);
      expect(notifications.shown, isEmpty);
      expect(exits, isEmpty);

      reload.complete();
      await tester.pump();
      expect(notifications.shown.single.title, startsWith('Sent'));
      await tester.pump(BackgroundMode.settleDelay * 2);
      expect(exits, ['exit']);
    });

    testOnMac('one the chain never shows is said so, and then the app quits', (tester) async {
      final notifications = FakeNotificationPlugin();
      final (:window, container: _, :exits) = await handedOver(tester, notifications);

      await _pressClose(tester, window);
      await tester.pump(const Duration(minutes: 4));
      expect(exits, isEmpty);

      await tester.pump(const Duration(minutes: 1, seconds: 10));
      await tester.pump();
      expect(notifications.shown.single.title, 'Send not confirmed');

      await tester.pump(BackgroundMode.settleDelay * 2);
      expect(exits, ['exit']);
    });

    testOnMac('Quit Now still quits at once', (tester) async {
      final (window: _, :container, :exits) = await handedOver(tester, FakeNotificationPlugin());

      container.read(backgroundModeProvider).quitNow();

      expect(exits, ['forced']);
    });

    testOnMac('a wallet reset lets the app go', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (window: _, :container, exits: _) = await handedOver(tester, FakeNotificationPlugin(), realLogout: true);
      expect(container.read(pendingWorkProvider), isTrue);

      await container.read(walletPresenceProvider.notifier).wipeWallet();
      await tester.pumpAndSettle();

      expect(container.read(pendingWorkProvider), isFalse);
    });
  });

  group('staying awake', () {
    PendingTransactionEvent send() => PendingTransactionEvent(
      tempId: 'tx-1',
      from: mainAccount.accountId,
      to: 'qzBob',
      amount: BigInt.one,
      fee: BigInt.zero,
      timestamp: DateTime(2026),
    );

    PendingMultisigProposalEvent proposal() => PendingMultisigProposalEvent(
      tempId: 'proposal-1',
      multisigAddress: 'qzTeam',
      proposerId: mainAccount.accountId,
      recipient: 'qzBob',
      amount: BigInt.one,
      deposit: BigInt.zero,
      expiryBlock: 100,
      palletFee: BigInt.zero,
    );

    testOnMac('with nothing under way it is never asked for', (tester) async {
      final (:window, container: _, exits: _) = await _open(tester);

      expect(window.stayAwake, isEmpty);
    });

    testOnMac('is held while a send is watched, and let go when it settles', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      container.read(pendingTransactionsProvider.notifier).add(send());
      await tester.pump();
      expect(window.stayAwake, [true]);

      container.read(pendingTransactionsProvider.notifier).remove('tx-1');
      await tester.pump();
      expect(window.stayAwake, [true, false]);
    });

    testOnMac('is held while a proposal is watched, and let go when it settles', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      container.read(pendingMultisigProposalsProvider.notifier).add(proposal());
      await tester.pump();
      expect(window.stayAwake, [true]);

      container.read(pendingMultisigProposalsProvider.notifier).remove('proposal-1');
      await tester.pump();
      expect(window.stayAwake, [true, false]);
    });

    testOnMac('is held while an approval is watched, and let go when it settles', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      container
          .read(pendingMultisigApprovalsProvider.notifier)
          .add(
            PendingMultisigApprovalEvent(
              id: 'approval-1',
              multisigAddress: 'qzTeam',
              proposalId: 1,
              approverId: mainAccount.accountId,
              recipient: 'qzPayee',
              amount: BigInt.one,
              submittedAt: DateTime(2026),
            ),
          );
      await tester.pump();
      expect(window.stayAwake, [true]);

      container.read(pendingMultisigApprovalsProvider.notifier).remove('approval-1');
      await tester.pump();
      expect(window.stayAwake, [true, false]);
    });

    testOnMac('is held while an execution is watched, and let go when it settles', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);
      final execution = PendingMultisigExecutionEvent(
        tempId: 'execution-1',
        multisigAddress: 'qzTeam',
        proposalId: 1,
        executorId: mainAccount.accountId,
        recipient: 'qzBob',
        amount: BigInt.one,
      );

      container.read(pendingMultisigExecutionsProvider.notifier).add(execution);
      await tester.pump();
      expect(window.stayAwake, [true]);

      container.read(pendingMultisigExecutionsProvider.notifier).remove(execution.id);
      await tester.pump();
      expect(window.stayAwake, [true, false]);
    });

    testOnMac('is held while a cancellation is watched, and let go when it settles', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);
      final cancellation = PendingMultisigCancellationEvent(
        tempId: 'cancellation-1',
        multisigAddress: 'qzTeam',
        proposalId: 1,
        proposerId: mainAccount.accountId,
        recipient: 'qzBob',
        amount: BigInt.one,
      );

      container.read(pendingMultisigCancellationsProvider.notifier).add(cancellation);
      await tester.pump();
      expect(window.stayAwake, [true]);

      container.read(pendingMultisigCancellationsProvider.notifier).remove(cancellation.id);
      await tester.pump();
      expect(window.stayAwake, [true, false]);
    });

    testOnMac('is held once, until the last of several settles', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      container.read(pendingTransactionsProvider.notifier).add(send());
      container.read(pendingMultisigProposalsProvider.notifier).add(proposal());
      await tester.pump();
      container.read(pendingTransactionsProvider.notifier).remove('tx-1');
      await tester.pump();
      expect(window.stayAwake, [true]);

      container.read(pendingMultisigProposalsProvider.notifier).remove('proposal-1');
      await tester.pump();
      expect(window.stayAwake, [true, false]);
    });

    testOnMac('is held while a multisig creation is watched, and let go when it settles', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (:window, :container, exits: _) = await _open(tester);
      final creations = container.read(pendingMultisigCreationsProvider.notifier);
      await creations.ready;

      await creations.add(PendingMultisigCreationEvent.fromDraft(teamMultisig, networkFee: BigInt.one), teamMultisig);
      await tester.pump();
      expect(container.read(pendingWorkProvider), isTrue);
      expect(window.stayAwake, [true]);

      await creations.remove(teamMultisig.accountId);
      await tester.pump();
      expect(container.read(pendingWorkProvider), isFalse);
      expect(window.stayAwake, [true, false]);
    });

    testOnMac('is not asked for by the Send sheet being open with nothing sent', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      container.read(shellSheetProvider.notifier).open(ShellSheet.send);
      await tester.pumpAndSettle();

      expect(container.read(pendingWorkProvider), isFalse);
      expect(window.stayAwake, isEmpty);
    });

    testOnMac('is let go by a wallet reset', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final (:window, :container, exits: _) = await _open(tester, realLogout: true);
      container.read(pendingTransactionsProvider.notifier).add(send());
      await tester.pump();
      expect(window.stayAwake, [true]);

      await container.read(walletPresenceProvider.notifier).wipeWallet();
      await tester.pumpAndSettle();

      expect(window.stayAwake, [true, false]);
    });

    testOnWindowsAndLinux('Windows and Linux are asked nothing', (tester) async {
      final (:window, :container, exits: _) = await _open(tester);

      container.read(pendingTransactionsProvider.notifier).add(send());
      await tester.pump();

      expect(window.stayAwake, isEmpty);
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

    /// Calls [method] as the window does, and gives the app's answer.
    Future<Object?> fromNative(String method, [Object? arguments]) async {
      final answered = Completer<Object?>();
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        WindowChrome.channel.name,
        WindowChrome.channel.codec.encodeMethodCall(MethodCall(method, arguments)),
        (reply) => answered.complete(WindowChrome.channel.codec.decodeEnvelope(reply!)),
      );
      return answered.future;
    }

    test('is told the menu bar icon\'s labels', () async {
      await const BackgroundWindow().configure(_labels);

      expect(sent.single.method, 'setStatusItemLabels');
      expect(sent.single.arguments, {'openLabel': 'Open Quantus Wallet', 'quitLabel': 'Quit Quantus Wallet'});
    });

    test('is told the swaps in progress, for the menu bar icon', () async {
      await const BackgroundWindow().setSwaps(
        const StatusItemSwaps(
          title: 'Swap 2/4',
          swaps: [
            StatusItemSwap(
              swapId: 'swap-1',
              accountId: 'qzMain',
              label: '-250 QTC for 104.37 USDC on Arbitrum',
              steps: ['QTC sent', 'Confirming on Quantus', 'Swapping', 'Sending USDC to the recipient'],
              current: 1,
            ),
          ],
        ),
      );
      await const BackgroundWindow().setSwaps(StatusItemSwaps.none);

      expect([for (final call in sent) call.method], ['setStatusItemSwaps', 'setStatusItemSwaps']);
      expect(sent.first.arguments, {
        'title': 'Swap 2/4',
        'swaps': [
          {
            'swapId': 'swap-1',
            'accountId': 'qzMain',
            'label': '-250 QTC for 104.37 USDC on Arbitrum',
            'steps': ['QTC sent', 'Confirming on Quantus', 'Swapping', 'Sending USDC to the recipient'],
            'current': 1,
          },
        ],
      });
      expect(sent.last.arguments, {'title': null, 'swaps': <Object?>[]});
    });

    test('tells the app which swap was picked from the menu bar icon\'s menu', () async {
      final picked = <(String, String)>[];
      const BackgroundWindow().listen(
        onWillClose: () async => false,
        onDidOpen: () {},
        onOpenSwap: ({required swapId, required accountId}) => picked.add((swapId, accountId)),
      );

      await fromNative('openSwap', {'swapId': 'swap-1', 'accountId': 'qzSavings'});

      expect(picked, [('swap-1', 'qzSavings')]);
    });

    test('is asked to hide', () async {
      await const BackgroundWindow().hide();

      expect(sent.single.method, 'hideWindow');
    });

    test('is asked to stay awake', () async {
      await const BackgroundWindow().setStayAwake(true);

      expect(sent.single.method, 'setStayAwake');
      expect(sent.single.arguments, {'isAwake': true});
    });

    test('is answered only once the app is ready for the window to close, with whether to hide it', () async {
      final ready = Completer<bool>();
      var opened = 0;
      const BackgroundWindow().listen(
        onWillClose: () => ready.future,
        onDidOpen: () => opened++,
        onOpenSwap: ({required swapId, required accountId}) => fail('No swap was picked'),
      );
      Object? answer = 'unanswered';
      unawaited(fromNative('windowWillClose').then((reply) => answer = reply));
      await Future<void>.delayed(Duration.zero);
      expect(answer, 'unanswered');

      ready.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(answer, isTrue);

      await fromNative('windowDidOpen');
      expect(opened, 1);
    });
  });

  group('a swap in progress', () {
    const quitTitle = 'A Transaction Is Still Under Way';

    /// The app following [swaps], with 1Click as [device] answers for them.
    Future<_Opened> following(
      WidgetTester tester,
      List<ActiveSwap> swaps, {
      FakeWalletDevice? device,
      bool workUnderWay = false,
    }) {
      final onDevice = device ?? FakeWalletDevice();
      onDevice.storage.activeSwaps = swaps;
      return _open(tester, onDevice: onDevice, workUnderWay: workUnderWay);
    }

    /// 1Click answering that every swap asked about succeeded.
    void succeedAll(FakeWalletDevice device) =>
        device.swaps.status = (order) async => SwapOrder(quote: order.quote, status: SwapStatus.success);

    /// Cmd+Q or the menu bar icon's Quit, as the system passes it on.
    Future<AppExitResponse> requestQuit(WidgetTester tester) async {
      final response = await tester.binding.handleRequestAppExit();
      await tester.pumpAndSettle();
      return response;
    }

    /// The app without its shell, following [swaps] with 1Click as [oneClick]
    /// answers, its errors kept in [telemetry]. The test disposes of it.
    Future<({ProviderContainer container, FakeBackgroundWindow window, List<String> exits})> bare(
      WidgetTester tester,
      List<ActiveSwap> swaps,
      _RecordingTelemetry telemetry,
    ) async {
      final window = FakeBackgroundWindow();
      final exits = <String>[];
      final container = ProviderContainer(
        overrides: [
          ...shellOverrides(accounts: const [mainAccount], settings: FakeSettingsService()..activeSwaps = swaps),
          backgroundWindowProvider.overrideWithValue(window),
          telemetryProvider.overrideWithValue(telemetry),
          requestAppExitProvider.overrideWithValue(() => exits.add('exit')),
        ],
      );
      container.read(backgroundModeProvider);
      await tester.pump();
      return (container: container, window: window, exits: exits);
    }

    testOnMac('closing the window while a swap is in progress hides it and leaves the app running', (tester) async {
      final (:window, :container, :exits) = await following(tester, [fakeActiveSwap()]);

      await _pressClose(tester, window);

      expect(window.calls, ['hide']);
      expect(exits, isEmpty);
      expect(container.read(windowClosedProvider), isTrue);
    });

    testOnMac('closing it with only swaps that ended, await a deposit by hand, or are overdue quits', (tester) async {
      final (:window, :container, :exits) = await following(tester, [
        fakeActiveSwap(depositAddress: '0xswapped', status: SwapStatus.success),
        fakeActiveSwap(depositAddress: '0xawaited', swapOut: false, status: SwapStatus.pendingDeposit),
        fakeActiveSwap(
          depositAddress: '0xoverdue',
          deadline: clock.now().subtract(ActiveSwap.finishGrace + const Duration(minutes: 1)),
        ),
      ]);

      await _closeFromMenu(tester, container);

      expect(exits, ['exit']);
      expect(window.calls, isEmpty);
    });

    testOnMac('quitting with only a swap in progress quits without asking: the swap goes on without the app', (
      tester,
    ) async {
      final (:window, container: _, exits: _) = await following(tester, [fakeActiveSwap()]);

      expect(await requestQuit(tester), AppExitResponse.exit);

      expect(find.text(quitTitle), findsNothing);
      expect(window.calls, isEmpty);
    });

    testOnMac('quitting with work under way beside a swap still asks', (tester) async {
      await following(tester, [fakeActiveSwap()], workUnderWay: true);

      expect(await requestQuit(tester), AppExitResponse.cancel);

      expect(find.text(quitTitle), findsOneWidget);
    });

    testWidgets('a swap in progress the whole time the window is closed brings nothing back, and is not reported', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final telemetry = _RecordingTelemetry();
      final swap = fakeActiveSwap(deadline: clock.now().add(BackgroundMode.hiddenLimit * 4));
      final (:container, :window, :exits) = await bare(tester, [swap], telemetry);
      await _pressClose(tester, window);

      await tester.pump(BackgroundMode.hiddenLimit + const Duration(seconds: 1));

      expect(window.calls, ['hide']);
      expect(container.read(windowClosedProvider), isTrue);
      expect(exits, isEmpty);
      expect(telemetry.errors, isNot(contains('desktop_background_work_stuck')));
      container.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('work under way beside a swap at the limit still brings the window back, and is reported', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final telemetry = _RecordingTelemetry();
      final swap = fakeActiveSwap(deadline: clock.now().add(BackgroundMode.hiddenLimit * 4));
      final (:container, :window, :exits) = await bare(tester, [swap], telemetry);
      container.read(workHoldsProvider.notifier).hold(_work);
      await tester.pump();
      await _pressClose(tester, window);

      await tester.pump(BackgroundMode.hiddenLimit + const Duration(seconds: 1));

      expect(window.calls, ['hide', 'bringToFront']);
      expect(exits, isEmpty);
      expect(telemetry.errors, contains('desktop_background_work_stuck'));
      container.dispose();
      debugDefaultTargetPlatformOverride = null;
    });

    testOnMac('with the window closed, the app quits a moment after the last swap ends', (tester) async {
      final device = FakeWalletDevice();
      final (:window, container: _, :exits) = await following(tester, [fakeActiveSwap()], device: device);
      await _pressClose(tester, window);
      await tester.pump(SwapService.statusPollInterval * 3);
      expect(exits, isEmpty, reason: 'the swap is still in progress');

      succeedAll(device);
      await tester.pump(SwapService.statusPollInterval);
      expect(exits, isEmpty, reason: 'it quits a moment after, not at once');

      await tester.pump(BackgroundMode.settleDelay * 3);
      expect(exits, ['exit']);
    });

    testOnMac('with the window closed, a swap turning overdue lets the app quit, with no answer from 1Click', (
      tester,
    ) async {
      final device = FakeWalletDevice()..swaps.status = (_) => Completer<SwapOrder>().future;
      final turnsOverdue = clock.now().add(const Duration(minutes: 1));
      final (:window, container: _, :exits) = await following(tester, [
        fakeActiveSwap(deadline: turnsOverdue.subtract(ActiveSwap.finishGrace)),
      ], device: device);
      await _pressClose(tester, window);

      await tester.pump(const Duration(seconds: 59));
      expect(exits, isEmpty);

      await tester.pump(const Duration(seconds: 1) + BackgroundMode.settleDelay * 3);
      expect(exits, ['exit']);
      expect(window.stayAwake.last, isFalse);
    });

    testOnMac('the Mac is kept awake while a swap is in progress, from launch, and let go once it ends', (
      tester,
    ) async {
      final device = FakeWalletDevice();
      final (:window, container: _, exits: _) = await following(tester, [fakeActiveSwap()], device: device);
      expect(window.stayAwake, [true]);

      succeedAll(device);
      await tester.pump(SwapService.statusPollInterval);

      expect(window.stayAwake, [true, false]);
    });
  });
}
