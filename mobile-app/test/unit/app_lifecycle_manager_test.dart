import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/app_lifecycle_manager.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/services/history_polling_manager.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

/// Counts the config refreshes the lifecycle manager asks for.
final _geoAllowed = RemoteConfigModel.fromJson(const {'geoNearAllowed': true});

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  /// Pumps the lifecycle manager with [remote] behind the config and
  /// [localAuth] behind the prompt; the config is read once, as the home
  /// screen would. The controller is the real one unless [authenticated]
  /// pins a test controller's state.
  Future<LocalAuthService> pumpManager(
    WidgetTester tester,
    FakeRemoteConfigService remote, {
    required FakeLocalAuthentication localAuth,
    bool? authenticated = true,
  }) async {
    final authService = LocalAuthService.withDependencies(localAuth: localAuth, settingsService: FakeSettingsService());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteConfigProvider.overrideWith((ref) => RemoteConfigNotifier(remote)),
          localAuthServiceProvider.overrideWithValue(authService),
          if (authenticated != null)
            localAuthProvider.overrideWith((ref) => TestLocalAuthController(authenticated: authenticated)),
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
    final remote = FakeRemoteConfigService(_geoAllowed, remote: _geoAllowed);
    final prompt = Completer<bool>();
    final authService = await pumpManager(tester, remote, localAuth: FakeLocalAuthentication()..hold = prompt.future);

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
    final remote = FakeRemoteConfigService(_geoAllowed, remote: _geoAllowed);
    final authService = await pumpManager(
      tester,
      remote,
      localAuth: FakeLocalAuthentication()..hold = Completer<bool>().future,
    );
    unawaited(authService.authenticate());
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(remote.reads, 1);
  });

  testWidgets('a launch activated after its prompt was answered does not prompt again', (tester) async {
    // iOS reports `inactive` until the launch is activated; the first frame
    // and its prompt can both be done before that `resumed` arrives.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final localAuth = FakeLocalAuthentication();
    await pumpManager(
      tester,
      FakeRemoteConfigService(_geoAllowed, remote: _geoAllowed),
      localAuth: localAuth,
      authenticated: null,
    );
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(AppLifecycleManager)));
    expect(localAuth.authenticateCalls, 1);
    expect(container.read(localAuthProvider).isAuthenticated, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(localAuth.authenticateCalls, 1);
    expect(container.read(localAuthProvider).isAuthenticated, isTrue);
  });
}
