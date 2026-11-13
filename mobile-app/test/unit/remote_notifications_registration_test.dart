import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/remote_notifications_registration.dart';

import '../fakes.dart';

void main() {
  const address = 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda';

  late FakePushRegistration push;
  late FakeTelemetry telemetry;

  ProviderContainer containerWith({required bool remoteNotifications}) {
    final container = ProviderContainer(
      overrides: [
        ...testWalletCoreOverrides(pushRegistration: push, telemetry: telemetry),
        remoteConfigServiceProvider.overrideWithValue(
          FakeRemoteConfigService(RemoteConfigModel.fromJson({'enableRemoteNotifications': remoteNotifications})),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    push = FakePushRegistration();
    telemetry = FakeTelemetry();
  });

  group('registerForRemoteNotificationsBestEffort', () {
    test('with an address registers that address only', () async {
      final container = containerWith(remoteNotifications: true);

      await registerForRemoteNotificationsBestEffort(container.read, insertAddress: address);

      expect(push.calls, ['registerAddress($address)']);
    });

    test('without an address registers the device', () async {
      final container = containerWith(remoteNotifications: true);

      await registerForRemoteNotificationsBestEffort(container.read);

      expect(push.calls, ['registerDevice']);
    });

    test('does nothing when remote notifications are disabled', () async {
      final container = containerWith(remoteNotifications: false);

      await registerForRemoteNotificationsBestEffort(container.read, insertAddress: address);
      await registerForRemoteNotificationsBestEffort(container.read);

      expect(push.calls, isEmpty);
    });

    test('reports a failure to telemetry and does not throw', () async {
      final container = containerWith(remoteNotifications: true);
      push.failure = Exception('push backend unreachable');

      await registerForRemoteNotificationsBestEffort(container.read, insertAddress: address);

      expect(telemetry.errors, ['registerForRemoteNotifications']);
    });
  });
}
