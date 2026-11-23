import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_core/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/notification_models.dart';

import '../fakes.dart';

void main() {
  test('NotificationNotifier hands an immediate push notification to LocalNotifications', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final localNotifications = FakeLocalNotifications();
    final container = ProviderContainer(overrides: testWalletCoreOverrides(localNotifications: localNotifications));
    addTearDown(container.dispose);
    final notification = NotificationData(
      id: 'n-1',
      accountId: makeAccount(0).accountId,
      type: NotificationType.info,
      source: NotificationSource.push,
      title: 'Received',
      message: '1 QTC',
      accountName: 'Account 0',
      timestamp: DateTime(2026),
    );

    await container.read(notificationProvider.notifier).addNotification(notification);

    expect(localNotifications.shown, [same(notification)]);
  });
}
