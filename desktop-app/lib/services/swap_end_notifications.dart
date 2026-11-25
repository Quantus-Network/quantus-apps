import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/notification_status.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/services/notification_delivery.dart';
import 'package:quantus_desktop_wallet/utils/swap_words.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/swap/swap_progress.dart';

/// Notifies how a followed swap ended, as 1Click tells it while the app runs:
/// swapped, refunded or failed; and, before that, a deposit that came short,
/// which is refunded once its window closes. Each says what the swap was about
/// as its row does.
///
/// Only a change learned in this run is told: a swap that had ended before the
/// app started was told then, or is in its row. One that ended while the app
/// was not running is told at its first poll. One learned before the system
/// has said whether it shows notifications is told once it has, if the swap
/// is still followed, and keeps the app running with its window closed until
/// then. A swap's steps on its way are not told, nor a deposit by hand that
/// never came: the person did not send one.
class SwapEndNotifications {
  SwapEndNotifications(this._ref) {
    _ref.listen<List<ActiveSwap>>(activeSwapsProvider, _onChanged);
    _ref.listen<NotificationStatus>(desktopLocalNotificationsProvider, (_, status) => _onStatus(status));
  }

  final Ref _ref;

  /// What was learned before the system said whether it shows notifications,
  /// each with the swap as it was then, while the swap is still followed.
  final _untold = <({ActiveSwap swap, String id})>[];

  /// Whether the system has yet to say whether it shows notifications: they
  /// are starting, or macOS has not had the person's answer.
  static bool _unanswered(NotificationStatus status) =>
      status is NotificationsStarting || status is NotificationsNotAsked;

  void _onChanged(List<ActiveSwap>? before, List<ActiveSwap> now) {
    if (before == null) return;
    final followed = {for (final swap in now) swap.id};
    _untold.removeWhere((untold) => !followed.contains(untold.swap.id));
    final statusBefore = {for (final swap in before) swap.id: swap.order.status};
    for (final swap in now) {
      final was = statusBefore[swap.id];
      final status = swap.order.status;
      if (was == null || was == status) continue;
      if (status.isFinal) {
        _tell(swap, id: 'swap_end_${swap.id}');
      } else if (status == SwapStatus.incompleteDeposit) {
        _tell(swap, id: 'swap_short_${swap.id}');
      }
    }
    _ref.read(swapEndsUntoldProvider.notifier).set(_untold.isNotEmpty);
  }

  void _tell(ActiveSwap swap, {required String id}) {
    if (_unanswered(_ref.read(desktopLocalNotificationsProvider))) {
      _untold.add((swap: swap, id: id));
    } else {
      _notify(swap, id: id);
    }
  }

  /// Once the system has answered, hands over what was learned before, for
  /// [NotificationDelivery] to show if it may.
  void _onStatus(NotificationStatus status) {
    if (_unanswered(status) || _untold.isEmpty) return;
    final untold = [..._untold];
    _untold.clear();
    for (final (:swap, :id) in untold) {
      _notify(swap, id: id);
    }
    // Only now: a notification handed over keeps the app running on its own.
    _ref.read(swapEndsUntoldProvider.notifier).set(false);
  }

  void _notify(ActiveSwap swap, {required String id}) {
    final l10n = _ref.read(l10nProvider);
    final fmt = _ref.read(numberFormattingServiceProvider);
    final standing = swapStandingWords(
      l10n,
      fmt,
      swap,
      swapProgressViewOf(swap, clock.now()),
      preflight: _ref.read(swapPreflightProvider) != null,
    );
    final (:amount, :foreignAmount, :network, what: _) = swapAmountWords(l10n, fmt, swap);
    _ref
        .read(notificationDeliveryProvider)
        .show(
          id: id,
          accountId: swap.accountId,
          accountName: swap.accountName,
          extrinsicHash: null,
          swapId: swap.id,
          intent: NotificationIntent.others,
          title: standing.label,
          body: l10n.desktopNotificationSwapBody(amount, foreignAmount, network),
        );
  }
}

final swapEndNotificationsProvider = Provider<SwapEndNotifications>(SwapEndNotifications.new);
