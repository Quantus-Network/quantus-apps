import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String notificationConfigKey = 'notification_config';

final notificationConfigProvider = StateNotifierProvider<NotificationConfigNotifier, NotificationConfig>((ref) {
  return NotificationConfigNotifier();
});

class NotificationConfigNotifier extends StateNotifier<NotificationConfig> {
  NotificationConfigNotifier()
    : super(
        const NotificationConfig(
          enabled: true,
          sound: true,
          vibration: true,
          showBadge: true,
          sentTokensEnabled: true,
          receivedTokensEnabled: true,
          recoveryTimerEndingEnabled: true,
          reversibleTransactionsEnabled: true,
        ),
      ) {
    loaded = _loadConfig();
  }

  /// Completes once the saved config, if any, has replaced the defaults.
  late final Future<void> loaded;

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(notificationConfigKey);

      if (configJson != null) {
        state = NotificationConfig.fromJson(Map<String, dynamic>.from(jsonDecode(configJson)));
      }
    } catch (e) {
      quantusPrint('Error loading notification config: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(notificationConfigKey, jsonEncode(state.toJson()));
    } catch (e) {
      quantusPrint('Error saving notification config: $e');
    }
  }

  Future<void> updateConfig(NotificationConfig newConfig) async {
    state = newConfig;
    await _saveConfig();
  }
}
