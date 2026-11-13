import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/desktop_local_notifications.dart';
import 'package:wallet_core/models/notification_models.dart';

void main() {
  test('desktop local notifications are not implemented: showing a notification fails', () async {
    const localNotifications = DesktopLocalNotifications();
    final notification = NotificationData(
      id: 'n-1',
      accountId: 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda',
      type: NotificationType.info,
      source: NotificationSource.push,
      title: 'Received',
      message: '1 QTC',
      accountName: 'Account 1',
      timestamp: DateTime(2026),
    );

    await expectLater(
      localNotifications.showOrScheduleNotification(notification),
      throwsA(
        isA<UnimplementedError>().having(
          (e) => e.message,
          'message',
          contains('Desktop local notifications are not implemented'),
        ),
      ),
    );
  });
}
