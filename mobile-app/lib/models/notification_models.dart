import 'dart:io';

import 'package:quantus_sdk/quantus_sdk.dart';

/// Notification types as specified in requirements
enum NotificationType {
  warning, // Transaction failed
  alert, // Account balance is 0
  success, // New account added
  reminder, // Reversible transaction reminder
  info, // General information
}

/// Notification intent for granular control
enum NotificationIntent { sentTokens, receivedTokens, recoveryTimerEnding, reversibleTransactions, others }

/// Source of the notification
enum NotificationSource {
  local, // App-generated alerts
  push, // Local push notifications
  remote, // Server push notifications (stub for future)
}

/// App-level notification configuration (what the user wants in-app)
class NotificationConfig {
  final bool enabled;
  final bool sound;
  final bool vibration;
  final bool showBadge;

  // Granular notification intent controls
  final bool sentTokensEnabled;
  final bool receivedTokensEnabled;
  final bool recoveryTimerEndingEnabled;
  final bool reversibleTransactionsEnabled;

  const NotificationConfig({
    required this.enabled,
    required this.sound,
    required this.vibration,
    required this.showBadge,
    required this.sentTokensEnabled,
    required this.receivedTokensEnabled,
    required this.recoveryTimerEndingEnabled,
    required this.reversibleTransactionsEnabled,
  });

  factory NotificationConfig.fromJson(Map<String, dynamic> json) {
    return NotificationConfig(
      enabled: json['enabled'] ?? true,
      sound: json['sound'] ?? true,
      vibration: json['vibration'] ?? true,
      showBadge: json['showBadge'] ?? true,
      sentTokensEnabled: json['sentTokensEnabled'] ?? true,
      receivedTokensEnabled: json['receivedTokensEnabled'] ?? true,
      recoveryTimerEndingEnabled: json['recoveryTimerEndingEnabled'] ?? true,
      reversibleTransactionsEnabled: json['reversibleTransactionsEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'sound': sound,
      'vibration': vibration,
      'showBadge': showBadge,
      'sentTokensEnabled': sentTokensEnabled,
      'receivedTokensEnabled': receivedTokensEnabled,
      'recoveryTimerEndingEnabled': recoveryTimerEndingEnabled,
      'reversibleTransactionsEnabled': reversibleTransactionsEnabled,
    };
  }

  NotificationConfig copyWith({
    bool? enabled,
    bool? sound,
    bool? vibration,
    bool? showBadge,
    bool? sentTokensEnabled,
    bool? receivedTokensEnabled,
    bool? recoveryTimerEndingEnabled,
    bool? reversibleTransactionsEnabled,
  }) {
    return NotificationConfig(
      enabled: enabled ?? this.enabled,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      showBadge: showBadge ?? this.showBadge,
      sentTokensEnabled: sentTokensEnabled ?? this.sentTokensEnabled,
      receivedTokensEnabled: receivedTokensEnabled ?? this.receivedTokensEnabled,
      recoveryTimerEndingEnabled: recoveryTimerEndingEnabled ?? this.recoveryTimerEndingEnabled,
      reversibleTransactionsEnabled: reversibleTransactionsEnabled ?? this.reversibleTransactionsEnabled,
    );
  }

  /// Check if a specific notification type is enabled
  bool isIntentEnabled(NotificationIntent intent) {
    switch (intent) {
      case NotificationIntent.sentTokens:
        return sentTokensEnabled;
      case NotificationIntent.receivedTokens:
        return receivedTokensEnabled;
      case NotificationIntent.recoveryTimerEnding:
        return recoveryTimerEndingEnabled;
      case NotificationIntent.reversibleTransactions:
        return reversibleTransactionsEnabled;
      case NotificationIntent.others:
        return true;
    }
  }
}

/// Main notification data model
class NotificationData {
  final String id;
  final String accountId;
  final NotificationType type;
  final NotificationIntent intent;
  final NotificationSource source;
  final String title;
  final String message;
  final String accountName;
  final DateTime timestamp;
  final DateTime? scheduledTime; // For reminders
  final DateTime? expiryTime; // When notification should auto-delete
  final Map<String, dynamic>? metadata; // For actions/deep links
  final bool persistent; // Should survive app restart

  const NotificationData({
    required this.id,
    required this.accountId,
    required this.type,
    required this.source,
    required this.title,
    required this.message,
    required this.accountName,
    required this.timestamp,
    this.scheduledTime,
    this.expiryTime,
    this.metadata,
    this.persistent = true,
    this.intent = NotificationIntent.others,
  });

  bool get hasValidScheduleTime => scheduledTime != null;

  // Create a copy with modified fields
  NotificationData copyWith({
    String? id,
    String? accountId,
    NotificationType? type,
    NotificationIntent? intent,
    NotificationSource? source,
    String? title,
    String? message,
    String? accountName,
    DateTime? timestamp,
    DateTime? scheduledTime,
    DateTime? expiryTime,
    Map<String, dynamic>? metadata,
    PendingTransactionEvent? transactionData,
    bool? persistent,
  }) {
    return NotificationData(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      intent: intent ?? this.intent,
      source: source ?? this.source,
      title: title ?? this.title,
      message: message ?? this.message,
      accountName: accountName ?? this.accountName,
      timestamp: timestamp ?? this.timestamp,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      expiryTime: expiryTime ?? this.expiryTime,
      metadata: metadata ?? this.metadata,
      persistent: persistent ?? this.persistent,
    );
  }

  // Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'type': type.name,
      'intent': intent.name,
      'source': source.name,
      'title': title,
      'message': message,
      'accountName': accountName,
      'timestamp': timestamp.toIso8601String(),
      'scheduledTime': scheduledTime?.toIso8601String(),
      'expiryTime': expiryTime?.toIso8601String(),
      'metadata': metadata,
      'persistent': persistent,
    };
  }

  // Create from JSON
  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      type: NotificationType.values.firstWhere((e) => e.name == json['type'], orElse: () => NotificationType.info),
      intent: NotificationIntent.values.firstWhere(
        (e) => e.name == json['intent'],
        orElse: () => NotificationIntent.others,
      ),
      source: NotificationSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => NotificationSource.local,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      accountName: json['accountName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      scheduledTime: json['scheduledTime'] != null ? DateTime.parse(json['scheduledTime'] as String) : null,
      expiryTime: json['expiryTime'] != null ? DateTime.parse(json['expiryTime'] as String) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      persistent: json['persistent'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationData && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Specific notification types for type safety
class NotificationTemplates {
  static int scheduleTimeBufferInSeconds = 3;

  static NotificationData transactionFailed({
    required Account? account,
    required PendingTransactionEvent transactionData,
    required String errorMessage,
  }) {
    return NotificationData(
      id: 'tx_failed_${transactionData.id}_${DateTime.now().millisecondsSinceEpoch}',
      accountId: account?.accountId ?? 'Undefined',
      type: NotificationType.warning,
      source: NotificationSource.push,
      title: 'Transaction Failed',
      message: errorMessage,
      accountName: account?.name ?? 'Undefined',
      timestamp: DateTime.now(),
      persistent: true,
      metadata: transactionData.toJson(),
    );
  }

  static NotificationData balanceLow({required Account? account}) {
    final accountId = account?.accountId ?? 'Undefined';

    return NotificationData(
      id: 'balance_low_${accountId}_${DateTime.now().millisecondsSinceEpoch}',
      accountId: account?.accountId ?? 'Undefined',
      type: NotificationType.alert,
      source: NotificationSource.local,
      title: 'Low Balance Alert',
      message: 'Your account balance is at or near the existential deposit.',
      accountName: account?.name ?? 'Undefined',
      timestamp: DateTime.now(),
      persistent: true,
      metadata: {'accountId': accountId},
    );
  }

  static NotificationData accountAdded({required Account? account}) {
    final accountId = account?.accountId ?? 'Undefined';

    return NotificationData(
      id: 'account_added_${accountId}_${DateTime.now().millisecondsSinceEpoch}',
      accountId: account?.accountId ?? 'Undefined',
      type: NotificationType.success,
      source: NotificationSource.local,
      title: 'Account Added',
      message: 'A new account has been successfully added to your wallet.',
      accountName: account?.name ?? 'Undefined',
      timestamp: DateTime.now(),
      persistent: true,
      metadata: {'accountId': accountId},
    );
  }

  static NotificationData reversibleTransactionReminder({
    required Account? account,
    required ReversibleTransferEvent transactionData,
  }) {
    final now = DateTime.now();
    final scheduleDistance = transactionData.scheduledAt.difference(now);

    DateTime reminderTime;
    Duration reminderDuration;

    if (scheduleDistance.inHours < 2) {
      reminderDuration = scheduleDistance;
      // Ensure the scheduled date is in the future
      reminderTime = now.add(Duration(seconds: scheduleTimeBufferInSeconds));
    } else {
      reminderDuration = const Duration(hours: 2);
      reminderTime = transactionData.scheduledAt.subtract(reminderDuration);
    }

    return NotificationData(
      id: 'reversible_reminder_${transactionData.id}_${DateTime.now().millisecondsSinceEpoch}',
      accountId: account?.accountId ?? 'Undefined',
      type: NotificationType.reminder,
      intent: NotificationIntent.reversibleTransactions,
      source: NotificationSource.push,
      title: 'Reversible Transaction Reminder',
      message: 'Your reversible transaction will execute in ${_formatDuration(reminderDuration)}',
      accountName: account?.name ?? 'Undefined',
      timestamp: DateTime.now(),
      scheduledTime: reminderTime,
      expiryTime: transactionData.scheduledAt,
      persistent: true,
      metadata: transactionData.toJson(),
    );
  }

  static NotificationData tokenSent({required Account? account, required TransferEvent transactionData}) {
    final tokenString = _formatAmount(transactionData.amount);

    return NotificationData(
      id: 'token_sent_${transactionData.id}_${DateTime.now().millisecondsSinceEpoch}',
      accountId: account?.accountId ?? 'Undefined',
      type: NotificationType.success,
      intent: NotificationIntent.sentTokens,
      source: NotificationSource.local,
      title: '$tokenString Sent',
      message: 'You just sent $tokenString to ${transactionData.to}',
      accountName: account?.name ?? 'Undefined',
      timestamp: DateTime.now(),
      persistent: true,
      metadata: transactionData.toJson(),
    );
  }

  static NotificationData tokenReceived({required Account? account, required TransferEvent transactionData}) {
    final tokenString = _formatAmount(transactionData.amount);

    return NotificationData(
      id: 'token_received_${transactionData.id}_${DateTime.now().millisecondsSinceEpoch}',
      accountId: account?.accountId ?? 'Undefined',
      type: NotificationType.info,
      intent: NotificationIntent.receivedTokens,
      source: NotificationSource.local,
      title: '$tokenString Received',
      message: 'You just received $tokenString from ${transactionData.from}',
      accountName: account?.name ?? 'Undefined',
      timestamp: DateTime.now(),
      persistent: true,
      metadata: transactionData.toJson(),
    );
  }

  static String _formatAmount(BigInt amount) {
    final localeConfig = LocaleNumberConfig.fromLocale(Platform.localeName);
    final NumberFormattingService formattingService = NumberFormattingService(localeConfig: localeConfig);
    return formattingService.formatBalance(amount, addSymbol: true);
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''}';
    } else {
      return '$minutes minute${minutes > 1 ? 's' : ''}';
    }
  }
}
