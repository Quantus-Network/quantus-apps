import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/app_lifecycle_manager.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/history_polling_manager.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

/// Counts the config refreshes the lifecycle manager asks for.
class _CountingRemoteConfigService extends FakeRemoteConfigService {
  _CountingRemoteConfigService(super.config);

  int reads = 0;

  @override
  Future<RemoteConfigModel?> readRemoteConfig() async {
    reads++;
    return config;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  /// Pumps the lifecycle manager with [remote] behind the config and a held
  /// authentication prompt; the config is read once, as the home screen would.
  Future<LocalAuthService> pumpManager(
    WidgetTester tester,
    _CountingRemoteConfigService remote, {
    required Future<bool> prompt,
  }) async {
    final authService = LocalAuthService.withDependencies(
      localAuth: FakeLocalAuthentication()..hold = prompt,
      settingsService: FakeSettingsService(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteConfigProvider.overrideWith((ref) => RemoteConfigNotifier(remote)),
          localAuthServiceProvider.overrideWithValue(authService),
          localAuthProvider.overrideWith((ref) => TestLocalAuthController(authenticated: true)),
          historyPollingManagerProvider.overrideWithValue(FakeHistoryPollingManager()),
          isOnlineProvider.overrideWith((ref) => true),
          networkStatusProvider.overrideWith((ref) => Stream.value(NetworkStatus.online)),
        ],
        child: const AppLifecycleManager(child: SizedBox()),
      ),
    );
    ProviderScope.containerOf(tester.element(find.byType(AppLifecycleManager))).read(remoteConfigProvider);
    await tester.pump();
    expect(remote.reads, 1);
    return authService;
  }

  testWidgets('a backgrounding during the auth prompt still re-checks the location on resume', (tester) async {
    final remote = _CountingRemoteConfigService(RemoteConfigModel.fromJson(const {'geoNearAllowed': true}));
    final prompt = Completer<bool>();
    final authService = await pumpManager(tester, remote, prompt: prompt.future);

    final authenticating = authService.authenticate();
    await tester.pump();
    expect(authService.isAuthenticating, isTrue);

    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    expect(remote.reads, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(remote.reads, 2);

    prompt.complete(true);
    expect(await authenticating, isTrue);
  });

  testWidgets('a prompt that only makes the app inactive does not re-check the location', (tester) async {
    final remote = _CountingRemoteConfigService(RemoteConfigModel.fromJson(const {'geoNearAllowed': true}));
    final authService = await pumpManager(tester, remote, prompt: Completer<bool>().future);
    unawaited(authService.authenticate());
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(remote.reads, 1);
  });
}
