import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/wallet_core_overrides.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';

class _Telemetry implements Telemetry {
  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) {}
}

class _PushRegistration implements PushRegistration {
  @override
  Future<void> registerDevice() async {}

  @override
  Future<void> registerAddress(String address) async {}

  @override
  Future<void> unregister() async {}
}

class _LocalNotifications implements LocalNotifications {
  @override
  Future<void> showOrScheduleNotification(NotificationData notification) async {}
}

/// The message of whatever a failed provider read throws; Riverpod may wrap
/// the provider's own error.
String _readFailure(void Function() read) {
  try {
    read();
  } catch (e) {
    return '$e';
  }
  fail('the read did not throw');
}

void main() {
  test('walletCoreOverrides binds each provider to what the app passed', () {
    final telemetry = _Telemetry();
    final pushRegistration = _PushRegistration();
    final localNotifications = _LocalNotifications();
    final container = ProviderContainer(
      overrides: walletCoreOverrides(
        telemetry: (_) => telemetry,
        pushRegistration: (_) => pushRegistration,
        localNotifications: (_) => localNotifications,
      ),
    );
    addTearDown(container.dispose);

    expect(container.read(telemetryProvider), same(telemetry));
    expect(container.read(pushRegistrationProvider), same(pushRegistration));
    expect(container.read(localNotificationsProvider), same(localNotifications));
  });

  test('a seam provider read without walletCoreOverrides throws and names walletCoreOverrides', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final failures = {
      'telemetryProvider': _readFailure(() => container.read(telemetryProvider)),
      'pushRegistrationProvider': _readFailure(() => container.read(pushRegistrationProvider)),
      'localNotificationsProvider': _readFailure(() => container.read(localNotificationsProvider)),
    };

    for (final MapEntry(key: provider, value: message) in failures.entries) {
      expect(message, contains(provider));
      expect(message, contains('walletCoreOverrides'));
    }
  });
}
