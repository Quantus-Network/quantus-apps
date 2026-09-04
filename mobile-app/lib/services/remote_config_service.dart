import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

const String remoteConfigCacheKey = 'remote_config_cache_v1';

/// Remote config never blocks or breaks the wallet: an unreachable quersi
/// server or a bad payload leaves the current config (last fetched, else the
/// in-code defaults) in effect.
class RemoteConfigService {
  final QuersiService _quersiService;
  final SettingsService _settingsService;

  RemoteConfigService({QuersiService? quersiService, SettingsService? settingsService})
    : _quersiService = quersiService ?? QuersiService(),
      _settingsService = settingsService ?? SettingsService();

  /// Null when quersi cannot be reached or answers with a bad payload.
  Future<RemoteConfigModel?> readRemoteConfig() async {
    try {
      return await _quersiService.getRemoteConfig();
    } catch (error) {
      quantusPrint('Remote config remote read failed, keeping current config: $error');
      return null;
    }
  }

  RemoteConfigModel readLocalConfig() {
    // In debug builds never trust the persisted cache: stale flags from an
    // earlier run can poison local state. Always reset to in-code defaults.
    if (kDebugMode) return _resetToDefaults();

    final jsonString = _settingsService.getString(remoteConfigCacheKey);
    if (jsonString == null || jsonString.isEmpty) return _resetToDefaults();

    try {
      return RemoteConfigModel.fromJson(jsonDecode(jsonString));
    } catch (error) {
      quantusPrint('Remote config cache unreadable, resetting to defaults: $error');
      return _resetToDefaults();
    }
  }

  RemoteConfigModel _resetToDefaults() {
    cacheConfig(RemoteConfigModel.defaults.toCacheJson());
    return RemoteConfigModel.defaults;
  }

  Future<void> cacheConfig(Object json) async {
    try {
      await _settingsService.setString(remoteConfigCacheKey, jsonEncode(json));
    } catch (error) {
      quantusPrint('Remote config local save failed: $error');
    }
  }
}
