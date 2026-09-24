import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'dart:async';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/remote_config_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});

final remoteConfigProvider = StateNotifierProvider<RemoteConfigNotifier, RemoteConfigModel>((ref) {
  return RemoteConfigNotifier(ref.read(remoteConfigServiceProvider));
});

class RemoteConfigNotifier extends StateNotifier<RemoteConfigModel> {
  final RemoteConfigService _service;
  bool _isRefreshingRemote = false;

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
        quantusPrint('Remote config remote refresh failed: $e');
      } finally {
        _isRefreshingRemote = false;
      }
    }());
  }
}
