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

  /// Counts refreshes. An answer to an older refresh is discarded: the device
  /// may have moved since that request went out.
  int _generation = 0;
  bool _refreshQueued = false;
  Future<void>? _inFlight;

  /// Completes once no refresh is in flight. A caller about to act on the
  /// location waits for this rather than reading a verdict that is being
  /// replaced.
  Future<void> get settled => _inFlight ?? Future.value();

  /// The cached flags, except the location verdict: the device may have moved
  /// since it was cached, so swap stays hidden until this launch's server
  /// answer allows it.
  RemoteConfigNotifier(this._service) : super(_service.readLocalConfig().copyWith(geoNearAllowed: false)) {
    syncConfig();
  }

  /// Refreshes the flags in the background and completes once the latest
  /// answer is in. The location verdict is revoked before the request goes
  /// out: the device may have moved since the last answer, so swap waits for
  /// this one. The other flags keep their values. A refresh asked for while
  /// one is in flight makes that one's answer obsolete and runs as soon as it
  /// ends, so the latest location is always the one checked.
  Future<void> syncConfig() {
    _generation++;
    _refreshQueued = true;
    if (state.geoNearAllowed) state = state.copyWith(geoNearAllowed: false);
    return _inFlight ??= _refreshWhileQueued().whenComplete(() => _inFlight = null);
  }

  Future<void> _refreshWhileQueued() async {
    while (_refreshQueued) {
      _refreshQueued = false;
      final generation = _generation;
      try {
        final remote = await _service.readRemoteConfig();
        if (generation == _generation && remote != null && remote != state) {
          _service.cacheConfig(remote.toCacheJson());
          state = remote;
        }
      } catch (e) {
        quantusPrint('Remote config remote refresh failed: $e');
      }
    }
  }
}
