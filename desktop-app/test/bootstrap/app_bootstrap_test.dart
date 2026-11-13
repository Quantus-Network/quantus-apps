import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_desktop_wallet/services/desktop_local_notifications.dart';
import 'package:quantus_desktop_wallet/services/desktop_push_registration.dart';
import 'package:quantus_desktop_wallet/services/desktop_telemetry.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';

void main() {
  test('buildApp binds the desktop implementations of the wallet_core seams', () {
    final scope = buildApp() as ProviderScope;
    final container = ProviderContainer(overrides: scope.overrides);
    addTearDown(container.dispose);

    expect(container.read(telemetryProvider), isA<DesktopTelemetry>());
    expect(container.read(pushRegistrationProvider), isA<DesktopPushRegistration>());
    expect(container.read(localNotificationsProvider), isA<DesktopLocalNotifications>());
  });
}
