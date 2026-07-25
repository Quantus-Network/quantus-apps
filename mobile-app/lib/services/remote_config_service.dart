import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

const String remoteConfigCacheKey = 'remote_config_cache_v1';

class RemoteConfigService {
  final TaskmasterService _taskmasterService = TaskmasterService();
  final SettingsService _settingsService = SettingsService();

  Future<RemoteConfigModel?> readRemoteConfig() async {
    try {
      final remoteData = await _taskmasterService.getRemoteConfig();
      return remoteData;
    } catch (error) {
      quantusDebugPrint('Remote config remote read failed: $error');
      return null;
    }
  }

  RemoteConfigModel readLocalConfig() {
    // In debug builds never trust the persisted cache: stale flags from an
    // earlier run can poison local state. Always reset to in-code defaults.
    if (kDebugMode) {
      cacheConfig(RemoteConfigModel.defaults.toCacheJson());
      return RemoteConfigModel.defaults;
    }

    final jsonString = _settingsService.getString(remoteConfigCacheKey);

    if (jsonString == null || jsonString.isEmpty) {
      cacheConfig(RemoteConfigModel.defaults.toCacheJson());
      return RemoteConfigModel.defaults;
    }

    final decoded = jsonDecode(jsonString);
    return RemoteConfigModel.fromJson(decoded);
  }

  Future<void> cacheConfig(Object json) async {
    try {
      await _settingsService.setString(remoteConfigCacheKey, jsonEncode(json));
    } catch (error) {
      quantusDebugPrint('Remote config local save failed: $error');
    }
  }
}
