import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/bootstrap/app_bootstrap.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/local_notifications_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';

void main() {
  test('buildApp binds the mobile implementations of the wallet_core seams', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    final scope = buildApp() as ProviderScope;
    final container = ProviderContainer(overrides: scope.overrides);
    addTearDown(container.dispose);

    expect(container.read(telemetryProvider), isA<TelemetryService>());
    expect(container.read(pushRegistrationProvider), isA<FirebaseMessagingService>());
    expect(container.read(localNotificationsProvider), isA<LocalNotificationsService>());
  });
}
