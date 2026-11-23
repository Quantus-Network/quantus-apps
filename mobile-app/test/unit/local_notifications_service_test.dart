import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/services/local_notifications_service.dart';

void main() {
  test('cancelAll reaches the notification plugin, and asks for no permission', () async {
    final messenger = TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(localNotificationsServiceProvider).cancelAll();

    expect(calls, ['cancelAll']);
  });
}
