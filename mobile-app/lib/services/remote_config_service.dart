import 'dart:convert';

import 'package:quantus_sdk/quantus_sdk.dart';

const String remoteConfigCacheKey = 'remote_config_cache_v1';

class RemoteConfigService {
  final TaskmasterService _taskmasterService = TaskmasterService();
  final SettingsService _settingsService = SettingsService();

  Future<RemoteConfigModel?> readRemoteConfig() async {
    try {
      final remoteData = await _taskmasterService.getRemoteConfig();
      return remoteData;
    } catch (error) {
      print('Remote config remote read failed: $error');
      return null;
    }
  }

  RemoteConfigModel readLocalConfig() {
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
      print('Remote config local save failed: $error');
    }
  }
}
