import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/services/desktop_push_registration.dart';
import 'package:quantus_desktop_wallet/services/desktop_telemetry.dart';
import 'package:quantus_desktop_wallet/services/mac_push_registration.dart';
import 'package:quantus_desktop_wallet/services/telemetry_user_store.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/swap_harness_service.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/user_approval.dart';

class _FixedUserStore implements TelemetryUserStore {
  @override
  Future<String> userId() async => 'ABC';
}

/// Never TelemetryDeck itself, nor this computer's app support folder.
final _telemetryOverrides = [
  telemetryHttpClientProvider.overrideWithValue(MockClient((_) async => http.Response('OK', 200))),
  telemetryUserStoreProvider.overrideWithValue(_FixedUserStore()),
];

void main() {
  test('buildApp binds the desktop implementations of the wallet_core seams', () {
    final scope = buildApp() as ProviderScope;
    final container = ProviderContainer(overrides: [...scope.overrides, ..._telemetryOverrides]);
    addTearDown(container.dispose);

    expect(container.read(telemetryProvider), isA<DesktopTelemetry>());
    expect(container.read(pushRegistrationProvider), isA<DesktopPushRegistration>());
    // The very one whose status the app shows.
    expect(
      container.read(localNotificationsProvider),
      same(container.read(desktopLocalNotificationsProvider.notifier)),
    );
  });

  test('buildApp sends to the desktop\'s own TelemetryDeck app, with the phone\'s salt, as test signals in debug', () {
    final scope = buildApp() as ProviderScope;
    final container = ProviderContainer(overrides: [...scope.overrides, ..._telemetryOverrides]);
    addTearDown(container.dispose);

    final telemetry = container.read(telemetryProvider) as DesktopTelemetry;
    expect(telemetry.appId, '56C8354B-882C-4A7E-A50C-971B41F8010E');
    expect(telemetry.salt, 'QDay');
    expect(telemetry.isTestMode, kDebugMode);
    expect(container.read(telemetryProvider), same(container.read(desktopTelemetryProvider)));
  });

  test('buildApp registers a Mac for pushes, and nothing on Windows or Linux', () {
    final scope = buildApp() as ProviderScope;
    for (final platform in [TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux]) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final container = ProviderContainer(overrides: [...scope.overrides, ..._telemetryOverrides]);
      addTearDown(container.dispose);

      expect(
        container.read(pushRegistrationProvider),
        platform == TargetPlatform.macOS ? isA<MacPushRegistration>() : isA<DesktopPushRegistration>(),
        reason: '$platform',
      );
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('buildApp binds the approval that wallet_core asks for to the system\'s own', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final scope = buildApp() as ProviderScope;
    final container = ProviderContainer(overrides: [...scope.overrides, ..._telemetryOverrides]);
    addTearDown(container.dispose);

    expect(container.read(userApprovalProvider), same(container.read(systemApprovalProvider)));
    expect(container.read(userApprovalProvider), isA<LocalAuthApproval>());
  });

  group('the swap test harness (SWAP_HARNESS)', () {
    test('stops the app from starting outside a debug build', () {
      expect(() => checkSwapHarnessDefine(enabled: true, isDebugBuild: false), throwsStateError);
      checkSwapHarnessDefine(enabled: true, isDebugBuild: true);
      checkSwapHarnessDefine(enabled: false, isDebugBuild: false);
    });

    test('runs every swap through the harness when on, and through 1Click when off', () {
      final withHarness = ProviderContainer(
        overrides: [...desktopWalletCoreOverrides(swapHarness: true), ..._telemetryOverrides],
      );
      addTearDown(withHarness.dispose);
      final without = ProviderContainer(
        overrides: [...desktopWalletCoreOverrides(swapHarness: false), ..._telemetryOverrides],
      );
      addTearDown(without.dispose);

      expect(withHarness.read(swapServiceProvider), isA<SwapHarnessService>());
      // Without it the swap service is 1Click's, read from the remote config.
      expect(without.read(swapHarnessServiceProvider), isNull);
    });
  });
}
