import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/notification_status.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/notification_click_provider.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

/// Hands the app's notifications to the system, when the person wants them
/// and the system allows them, and keeps the app running until each is on its
/// way.
class NotificationDelivery {
  /// How long a notification handed over still needs the app: macOS's
  /// notification plugin answers before macOS has taken it.
  static const settleDelay = Duration(seconds: 2);

  NotificationDelivery(this._ref) {
    _ref.onDispose(() {
      for (final timer in _settling) {
        timer.cancel();
      }
    });
  }

  final Ref _ref;

  /// One for each notification handed over less than [settleDelay] ago.
  final _settling = <Timer>{};

  /// Whether a notification was handed over so recently that quitting now
  /// could still lose it.
  bool get isSettling => _settling.isNotEmpty;

  /// Counts [delivering], which reports its own failures, as work under way
  /// until it is done.
  void holdWhile(Future<void> delivering) {
    final holds = _ref.read(workHoldsProvider.notifier);
    holds.hold(delivering);
    unawaited(delivering.whenComplete(() => holds.release(delivering)));
  }

  /// [amount] as a notification says it, with the token's symbol.
  String amountText(BigInt amount) {
    final formatted = _ref.read(numberFormattingServiceProvider).formatBalance(amount, smartDecimals: 4);
    return _ref.read(l10nProvider).commonAmountBalance(formatted, AppConstants.tokenSymbol);
  }

  /// Shows a notification when the person wants it and the system allows it.
  void show({
    required String id,
    required String accountId,
    required String accountName,
    required String? extrinsicHash,
    required NotificationIntent intent,
    required String title,
    required String body,
  }) {
    final config = _ref.read(notificationConfigProvider);
    if (!config.enabled || !config.isIntentEnabled(intent)) return;
    final status = _ref.read(desktopLocalNotificationsProvider);
    if (status is! NotificationsAllowed) {
      quantusPrint('Not notifying "$title": notifications are ${status.runtimeType}');
      return;
    }
    final notification = NotificationData(
      id: id,
      accountId: accountId,
      type: NotificationType.info,
      intent: intent,
      source: NotificationSource.local,
      title: title,
      message: body,
      accountName: accountName,
      timestamp: clock.now(),
      metadata: extrinsicHash == null ? null : {notificationHashKey: extrinsicHash},
      persistent: false,
    );
    holdWhile(_showNow(notification));
  }

  Future<void> _showNow(NotificationData notification) async {
    try {
      await _ref.read(desktopLocalNotificationsProvider.notifier).showOrScheduleNotification(notification);
      if (!_ref.mounted) return;
      late final Timer settled;
      settled = Timer(settleDelay, () => _settling.remove(settled));
      _settling.add(settled);
    } catch (e) {
      quantusPrint('Showing a notification failed: $e');
      _ref.read(telemetryProvider).sendError('desktop_notification_show_failed', error: e);
    }
  }
}

final notificationDeliveryProvider = Provider<NotificationDelivery>(NotificationDelivery.new);
