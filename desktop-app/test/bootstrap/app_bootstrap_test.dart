import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/services/desktop_push_registration.dart';
import 'package:quantus_desktop_wallet/services/desktop_telemetry.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/user_approval.dart';

void main() {
  test('buildApp binds the desktop implementations of the wallet_core seams', () {
    final scope = buildApp() as ProviderScope;
    final container = ProviderContainer(overrides: scope.overrides);
    addTearDown(container.dispose);

    expect(container.read(telemetryProvider), isA<DesktopTelemetry>());
    expect(container.read(pushRegistrationProvider), isA<DesktopPushRegistration>());
    // The very one whose status the app shows.
    expect(
      container.read(localNotificationsProvider),
      same(container.read(desktopLocalNotificationsProvider.notifier)),
    );
  });

  test('buildApp binds the approval that wallet_core asks for to the system\'s own', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final scope = buildApp() as ProviderScope;
    final container = ProviderContainer(overrides: scope.overrides);
    addTearDown(container.dispose);

    expect(container.read(userApprovalProvider), same(container.read(systemApprovalProvider)));
    expect(container.read(userApprovalProvider), isA<LocalAuthApproval>());
  });
}
