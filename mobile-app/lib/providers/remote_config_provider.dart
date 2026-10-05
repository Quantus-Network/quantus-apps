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

  Future<void> syncConfig() async {
    // Fetch remote in the background. This should not block startup feel.
    if (_isRefreshingRemote) return;
    _isRefreshingRemote = true;

    unawaited(() async {
      try {
        final remote = await _service.readRemoteConfig();
        if (remote == null) {
          _revokeGeo();
          return;
        }
        if (remote != state) {
          _service.cacheConfig(remote.toCacheJson());
          state = remote;
        }
      } catch (e) {
        quantusPrint('Remote config remote refresh failed: $e');
        _revokeGeo();
      } finally {
        _isRefreshingRemote = false;
      }
    }());
  }

  /// A refresh that did not reach the server leaves the location unknown, and
  /// unknown means no swap. The other flags keep their last known values.
  void _revokeGeo() {
    if (state.geoNearAllowed) state = state.copyWith(geoNearAllowed: false);
  }
}
