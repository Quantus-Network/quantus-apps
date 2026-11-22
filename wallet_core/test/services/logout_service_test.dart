import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/notification_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/services/logout_service.dart';

import '../fakes.dart';

Future<void> _turnNotificationsOff(ProviderContainer container) => container
    .read(notificationConfigProvider.notifier)
    .updateConfig(container.read(notificationConfigProvider).copyWith(enabled: false));

NotificationData _reminderIn(Duration delay) => NotificationData(
  id: 'reminder',
  accountId: 'account',
  type: NotificationType.reminder,
  intent: NotificationIntent.reversibleTransactions,
  source: NotificationSource.local,
  title: 'Reminder',
  message: 'A reversible send is about to run',
  accountName: 'Account',
  timestamp: DateTime.now(),
  scheduledTime: DateTime.now().add(delay),
);

NotificationData _shown(String id) => NotificationData(
  id: id,
  accountId: 'account',
  type: NotificationType.success,
  intent: NotificationIntent.sentTokens,
  source: NotificationSource.local,
  title: 'Sent',
  message: 'From Account',
  accountName: 'Account',
  timestamp: DateTime.now(),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a reset brings back the default notification settings', (tester) async {
    final container = ProviderContainer(overrides: WalletTestBed().overrides);
    await _turnNotificationsOff(container);

    await container.read(logoutServiceProvider).logout();
    await tester.pump();

    expect(container.read(notificationConfigProvider).enabled, isTrue);
    container.dispose();
  });

  testWidgets('a wipe that fails leaves the notification settings as they were', (tester) async {
    final bed = WalletTestBed()..substrate.logoutError = StateError('the wipe failed');
    final container = ProviderContainer(overrides: bed.overrides);
    await _turnNotificationsOff(container);

    await expectLater(container.read(logoutServiceProvider).logout(), throwsStateError);
    await tester.pump();

    expect(container.read(notificationConfigProvider).enabled, isFalse);
    container.dispose();
  });

  testWidgets('with a setting changed, a reminder scheduled before a reset does not fire after it', (tester) async {
    final container = ProviderContainer(overrides: WalletTestBed().overrides);
    // Only a config that differs from the defaults rebuilds the notifier.
    await container
        .read(notificationConfigProvider.notifier)
        .updateConfig(container.read(notificationConfigProvider).copyWith(sound: false));
    final notifications = container.read(notificationProvider.notifier);
    await tester.pump();
    await notifications.addNotification(_reminderIn(const Duration(hours: 1)));
    expect(notifications.getScheduledNotificationIds(), ['reminder']);

    await container.read(logoutServiceProvider).logout();
    // The next session's first use replaces the notifier.
    container.read(notificationProvider);
    await tester.pump();
    await tester.pump(const Duration(hours: 2));

    expect(tester.takeException(), isNull);
    expect(container.read(notificationProvider), isEmpty);
    container.dispose();
  });

  group('with the default notification settings', () {
    testWidgets('a reminder scheduled before a reset does not fire after it', (tester) async {
      final container = ProviderContainer(overrides: WalletTestBed().overrides);
      final notifications = container.read(notificationProvider.notifier);
      await tester.pump();
      await notifications.addNotification(_reminderIn(const Duration(hours: 1)));

      await container.read(logoutServiceProvider).logout();
      await tester.pump(const Duration(hours: 2));

      expect(tester.takeException(), isNull);
      expect(container.read(notificationProvider), isEmpty);
      await tester.pump();
      container.dispose();
    });

    testWidgets("a reset empties the old wallet's notifications", (tester) async {
      final container = ProviderContainer(overrides: WalletTestBed().overrides);
      container.read(notificationProvider);
      await tester.pump();
      await container.read(notificationProvider.notifier).addNotification(_shown('old'));
      await tester.pump();
      expect(container.read(notificationProvider), hasLength(1));

      await container.read(logoutServiceProvider).logout();

      expect(container.read(notificationProvider), isEmpty);
      await tester.pump();
      container.dispose();
    });

    testWidgets('the next notification saves only itself, and shows', (tester) async {
      final container = ProviderContainer(overrides: WalletTestBed().overrides);
      container.read(notificationProvider);
      await tester.pump();
      await container.read(notificationProvider.notifier).addNotification(_shown('old'));

      await container.read(logoutServiceProvider).logout();
      container.read(notificationProvider);
      await tester.pump();
      await container.read(notificationProvider.notifier).addNotification(_shown('new'));
      await tester.pump();

      expect(container.read(notificationProvider).map((n) => n.id), ['new']);
      final saved = (await SharedPreferences.getInstance()).getStringList(notificationsStorageKey)!;
      expect(saved.map((json) => jsonDecode(json)['id']), ['new']);
      container.dispose();
    });

    testWidgets('a wipe that fails leaves the list and the scheduled reminder in place', (tester) async {
      final bed = WalletTestBed()..substrate.logoutError = StateError('the wipe failed');
      final container = ProviderContainer(overrides: bed.overrides);
      final notifications = container.read(notificationProvider.notifier);
      await tester.pump();
      await notifications.addNotification(_shown('old'));
      await notifications.addNotification(_reminderIn(const Duration(hours: 1)));

      await expectLater(container.read(logoutServiceProvider).logout(), throwsStateError);

      expect(container.read(notificationProvider).map((n) => n.id), ['old']);
      expect(container.read(notificationProvider.notifier).getScheduledNotificationIds(), ['reminder']);
      container.dispose();
    });
  });

  group("the system's notifications", () {
    testWidgets('a reset cancels them', (tester) async {
      final bed = WalletTestBed();
      final container = ProviderContainer(overrides: bed.overrides);

      await container.read(logoutServiceProvider).logout();
      await tester.pump();

      expect(bed.localNotifications.cancelAllCalls, 1);
      container.dispose();
    });

    testWidgets('a wipe that fails leaves them', (tester) async {
      final bed = WalletTestBed()..substrate.logoutError = StateError('the wipe failed');
      final container = ProviderContainer(overrides: bed.overrides);

      await expectLater(container.read(logoutServiceProvider).logout(), throwsStateError);

      expect(bed.localNotifications.cancelAllCalls, 0);
      container.dispose();
    });

    testWidgets('when they cannot be cancelled, the reset still finishes and it is reported', (tester) async {
      final bed = WalletTestBed();
      bed.localNotifications.cancelAllError = StateError('the system refused');
      final container = ProviderContainer(overrides: bed.overrides);
      container
          .read(pendingTransactionsProvider.notifier)
          .add(
            PendingTransactionEvent(
              tempId: 'tx-1',
              from: 'qzFrom',
              to: 'qzTo',
              amount: BigInt.one,
              fee: BigInt.zero,
              timestamp: DateTime(2026),
            ),
          );

      await container.read(logoutServiceProvider).logout();
      await tester.pump();

      expect(bed.telemetry.errors, ['logout_cancel_notifications_failed']);
      // What comes after it in the reset still ran.
      expect(container.read(pendingTransactionsProvider), isEmpty);
      container.dispose();
    });
  });
}
