import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/notification_models.dart';
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
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(notificationConfigKey);

      if (configJson != null) {
        state = NotificationConfig.fromJson(Map<String, dynamic>.from(jsonDecode(configJson)));
      }
    } catch (e) {
      print('Error loading notification config: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(notificationConfigKey, jsonEncode(state.toJson()));
    } catch (e) {
      print('Error saving notification config: $e');
    }
  }

  Future<void> updateConfig(NotificationConfig newConfig) async {
    state = newConfig;
    await _saveConfig();
  }
}
