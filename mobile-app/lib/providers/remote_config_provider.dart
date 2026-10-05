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

  /// The cached flags, except the location verdict: the device may have moved
  /// since it was cached, so swap stays hidden until this launch's server
  /// answer allows it.
  RemoteConfigNotifier(this._service) : super(_service.readLocalConfig().copyWith(geoNearAllowed: false)) {
    syncConfig();
  }

  /// Refreshes the flags in the background. The location verdict is revoked
  /// before the request goes out: the device may have moved since the last
  /// answer, so swap waits for this one. The other flags keep their values.
  Future<void> syncConfig() async {
    if (_isRefreshingRemote) return;
    _isRefreshingRemote = true;
    if (state.geoNearAllowed) state = state.copyWith(geoNearAllowed: false);

    unawaited(() async {
      try {
        final remote = await _service.readRemoteConfig();
        if (remote != null && remote != state) {
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
