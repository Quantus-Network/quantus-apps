import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/notification_provider.dart';
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
}
