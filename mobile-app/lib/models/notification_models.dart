import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Notification types as specified in requirements
enum NotificationType {
  warning, // Transaction failed
  alert, // Account balance is 0
  success, // New account added
  reminder, // Reversible transaction reminder
  info, // General information
}

/// Source of the notification
enum NotificationSource {
  local, // App-generated alerts
  push, // Local push notifications
  remote, // Server push notifications (stub for future)
}

/// Transaction data for failed transaction notifications
class TransactionData {
  final String id;
  final String from;
  final String to;
  final BigInt amount;
  final BigInt? fee;
  final String? error;
  final DateTime timestamp;
  final TransactionState? state;

  const TransactionData({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    this.fee,
    this.error,
    required this.timestamp,
    this.state,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from,
      'to': to,
      'amount': amount.toString(),
      'fee': fee?.toString(),
      'error': error,
      'timestamp': timestamp.toIso8601String(),
      'state': state?.name,
    };
  }

  factory TransactionData.fromJson(Map<String, dynamic> json) {
    return TransactionData(
      id: json['id'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      amount: BigInt.parse(json['amount'] as String),
      fee: json['fee'] != null ? BigInt.parse(json['fee'] as String) : null,
      error: json['error'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      state: json['state'] != null
          ? TransactionState.values.firstWhere(
              (e) => e.name == json['state'],
              orElse: () => TransactionState.ready,
            )
          : null,
    );
  }
}

/// Main notification data model
class NotificationData {
  final String id;
  final NotificationType type;
  final NotificationSource source;
  final String title;
  final String message;
  final String accountName;
  final DateTime timestamp;
  final DateTime? scheduledTime; // For reminders
  final DateTime? expiryTime; // When notification should auto-delete
  final Map<String, dynamic>? metadata; // For actions/deep links
  final TransactionData? transactionData; // For failed transaction details
  final bool persistent; // Should survive app restart
  final VoidCallback? onViewDetails;

  const NotificationData({
    required this.id,
    required this.type,
    required this.source,
    required this.title,
    required this.message,
    required this.accountName,
    required this.timestamp,
    this.scheduledTime,
    this.expiryTime,
    this.metadata,
    this.transactionData,
    this.persistent = true,
    this.onViewDetails,
  });

  // Create a copy with modified fields
  NotificationData copyWith({
    String? id,
    NotificationType? type,
    NotificationSource? source,
    String? title,
    String? message,
    String? accountName,
    DateTime? timestamp,
    DateTime? scheduledTime,
    DateTime? expiryTime,
    Map<String, dynamic>? metadata,
    TransactionData? transactionData,
    bool? persistent,
    VoidCallback? onViewDetails,
  }) {
    return NotificationData(
      id: id ?? this.id,
      type: type ?? this.type,
      source: source ?? this.source,
      title: title ?? this.title,
      message: message ?? this.message,
      accountName: accountName ?? this.accountName,
      timestamp: timestamp ?? this.timestamp,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      expiryTime: expiryTime ?? this.expiryTime,
      metadata: metadata ?? this.metadata,
      transactionData: transactionData ?? this.transactionData,
      persistent: persistent ?? this.persistent,
      onViewDetails: onViewDetails ?? this.onViewDetails,
    );
  }

  // Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'source': source.name,
      'title': title,
      'message': message,
      'accountName': accountName,
      'timestamp': timestamp.toIso8601String(),
      'scheduledTime': scheduledTime?.toIso8601String(),
      'expiryTime': expiryTime?.toIso8601String(),
      'metadata': metadata,
      'transactionData': transactionData?.toJson(),
      'persistent': persistent,
    };
  }

  // Create from JSON
  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.info,
      ),
      source: NotificationSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => NotificationSource.local,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      accountName: json['accountName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'] as String)
          : null,
      expiryTime: json['expiryTime'] != null
          ? DateTime.parse(json['expiryTime'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      transactionData: json['transactionData'] != null
          ? TransactionData.fromJson(
              json['transactionData'] as Map<String, dynamic>,
            )
          : null,
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
  static NotificationData transactionFailed({
    required String accountName,
    required String transactionId,
    required String errorMessage,
    TransactionData? transactionData,
  }) {
    return NotificationData(
      id: 'tx_failed_${transactionId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.warning,
      source: NotificationSource.local,
      title: 'Transaction Failed',
      message: errorMessage,
      accountName: accountName,
      timestamp: DateTime.now(),
      persistent: true,
      metadata: {'transactionId': transactionId},
      transactionData: transactionData,
    );
  }

  static NotificationData balanceLow({
    required String accountName,
    required String accountId,
  }) {
    return NotificationData(
      id: 'balance_low_${accountId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.alert,
      source: NotificationSource.local,
      title: 'Low Balance Alert',
      message: 'Your account balance is at or near the existential deposit.',
      accountName: accountName,
      timestamp: DateTime.now(),
      persistent: true,
      metadata: {'accountId': accountId},
    );
  }

  static NotificationData accountAdded({
    required String accountName,
    required String accountId,
  }) {
    return NotificationData(
      id: 'account_added_${accountId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.success,
      source: NotificationSource.local,
      title: 'Account Added',
      message: 'A new account has been successfully added to your wallet.',
      accountName: accountName,
      timestamp: DateTime.now(),
      persistent: true,
      metadata: {'accountId': accountId},
    );
  }

  static NotificationData reversibleTransactionReminder({
    required String accountName,
    required String transactionId,
    required DateTime executionTime,
  }) {
    const reminderDuration = Duration(hours: 2);
    final reminderTime = executionTime.subtract(reminderDuration);
    return NotificationData(
      id: 'reversible_reminder_${transactionId}_${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.reminder,
      source: NotificationSource.push,
      title: 'Reversible Transaction Reminder',
      message:
          'Your reversible transaction will execute in ${reminderDuration.inHours} hours.',
      accountName: accountName,
      timestamp: DateTime.now(),
      scheduledTime: reminderTime,
      expiryTime: executionTime,
      persistent: true,
      metadata: {
        'transactionId': transactionId,
        'executionTime': executionTime.toIso8601String(),
      },
    );
  }
}
