import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
/// was not running is told at its first poll. A swap's steps on its way are
/// not told, nor a deposit by hand that never came: the person did not send
/// one.
class SwapEndNotifications {
  SwapEndNotifications(this._ref) {
    _ref.listen<List<ActiveSwap>>(activeSwapsProvider, _onChanged);
  }

  final Ref _ref;

  void _onChanged(List<ActiveSwap>? before, List<ActiveSwap> now) {
    if (before == null) return;
    final statusBefore = {for (final swap in before) swap.id: swap.order.status};
    for (final swap in now) {
      final was = statusBefore[swap.id];
      final status = swap.order.status;
      if (was == null || was == status) continue;
      if (status.isFinal) {
        _notify(swap, id: 'swap_end_${swap.id}');
      } else if (status == SwapStatus.incompleteDeposit) {
        _notify(swap, id: 'swap_short_${swap.id}');
      }
    }
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
          intent: NotificationIntent.others,
          title: standing.label,
          body: l10n.desktopNotificationSwapBody(amount, foreignAmount, network),
        );
  }
}

final swapEndNotificationsProvider = Provider<SwapEndNotifications>(SwapEndNotifications.new);
