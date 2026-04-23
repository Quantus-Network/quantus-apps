import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/firebase_options.dart';
import 'package:resonance_network_wallet/services/remote_config_service.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/shared/global_navigator_key.dart';

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});

final remoteConfigProvider = StateNotifierProvider<RemoteConfigNotifier, RemoteConfigModel>((ref) {
  return RemoteConfigNotifier(ref.read(remoteConfigServiceProvider));
});

class RemoteConfigNotifier extends StateNotifier<RemoteConfigModel> {
  final RemoteConfigService _service;
  bool _isRefreshingRemote = false;
  bool _isEnablingRemoteNotifications = false;

  RemoteConfigNotifier(this._service) : super(_service.readLocalConfig()) {
    syncConfig();
  }

  Future<void> syncConfig() async {
    // Fetch remote in the background. This should not block startup feel.
    if (_isRefreshingRemote) return;
    _isRefreshingRemote = true;

    unawaited(() async {
      try {
        final remote = await _service.readRemoteConfig();
        if (remote == null) return;

        if (remote != state) {
          _service.cacheConfig(remote.toCacheJson());
          state = remote;
        }
      } catch (e) {
        print('Remote config remote refresh failed: $e');
      } finally {
        _isRefreshingRemote = false;
      }
    }());
  }

  void registerRemoteRefreshListener(WidgetRef ref) {
    // using `listenManual` allows
    // setting up the side-effect listener from `initState`/async code.
    ref.listenManual<RemoteConfigModel>(remoteConfigProvider, (previous, next) {
      if (!next.enableRemoteNotifications) return;
      unawaited(_enableRemoteNotificationsIfNeeded(ref));
    });
  }

  Future<void> _enableRemoteNotificationsIfNeeded(WidgetRef ref) async {
    if (_isEnablingRemoteNotifications) return;
    _isEnablingRemoteNotifications = true;

    // If Firebase wasn't initialized at startup (because cached flags were false),
    // do it now.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.getOptionsForEnvironment());
    }

    final fcmService = ref.read(firebaseMessagingServiceProvider);
    await fcmService.init(); // This requests notification permission.

    // Ensure navigatorKey.currentState is attached before handling any initial message.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fcmService.setupNotificationTapHandlers(navigatorKey);
    });

    _isEnablingRemoteNotifications = false;
  }
}
