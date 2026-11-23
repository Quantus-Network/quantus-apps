import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/swap_preflight.dart';
import 'package:wallet_core/providers/active_swap_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/send/regular_send_strategy.dart';

/// How a confirmation ended. Each app says it in its own way.
@immutable
sealed class SwapConfirmOutcome {
  const SwapConfirmOutcome();
}

/// The swap is followed: its progress is there to show.
final class SwapConfirmed extends SwapConfirmOutcome {
  const SwapConfirmed();
}

/// There is nothing to say: the review went away before anything was sent,
/// or the deposit landed after the wallet logged out or moved on to another
/// swap, and is not followed.
final class SwapConfirmDropped extends SwapConfirmOutcome {
  const SwapConfirmDropped();
}

/// The live quote guarantees less or asks more than the one reviewed:
/// [quote] replaces the terms, and needs confirming again.
final class SwapTermsChanged extends SwapConfirmOutcome {
  const SwapTermsChanged(this.quote);

  final SwapQuote quote;
}

/// The listing changed under the confirmation: the swap is to be reviewed
/// again.
final class SwapListingChanged extends SwapConfirmOutcome {
  const SwapListingChanged();
}

/// Swaps are not allowed where the device now is.
final class SwapNotAllowed extends SwapConfirmOutcome {
  const SwapNotAllowed();
}

/// No live quote could be had, for the reason [message] gives.
final class SwapQuoteRefused extends SwapConfirmOutcome {
  const SwapQuoteRefused(this.message);

  final String message;
}

/// The device's approval was not given.
final class SwapApprovalRequired extends SwapConfirmOutcome {
  const SwapApprovalRequired();
}

/// The deposit could not be submitted.
final class SwapDepositFailed extends SwapConfirmOutcome {
  const SwapDepositFailed();
}

/// Confirms the swaps reviewed from [account], one review's worth: it lives
/// as long as the review does.
///
/// Confirming takes a live quote. When that guarantees less or asks more
/// than the one reviewed, its terms are handed back to be confirmed again. A
/// swap out of QTC then sends the deposit from [account], once the device's
/// owner approves; in preflight, and for a swap into QTC, the deposit is made
/// by hand. The swap is then followed.
class SwapConfirmation {
  SwapConfirmation({required this.account});

  final Account account;

  /// The live order last taken. It is kept until close to its deadline, so
  /// that confirming again reuses its deposit address.
  SwapOrder? _order;

  /// Bumped when the swap service is rebuilt; a confirmation that started
  /// under an older one stops where it is.
  int _generation = 0;

  /// Tells that the swap service was rebuilt, as when the asset QTC is
  /// listed under changes: the live order kept is the old listing's, and an
  /// answer the old service is still owed is discarded.
  void serviceRebuilt() {
    _generation++;
    _order = null;
  }

  bool _sendsDeposit(SwapQuote quote, SwapPreflight? preflight) => quote.fromToken.isQuantus && preflight == null;

  /// Confirms [quote] as reviewed, with the review's [ref]. [isActive] says
  /// whether the review is still there: once it is gone nothing more is
  /// started, but a deposit already going out is seen through and its swap
  /// followed.
  Future<SwapConfirmOutcome> confirm(WidgetRef ref, SwapQuote quote, {required bool Function() isActive}) async {
    final l10n = ref.read(l10nProvider);
    final generation = _generation;
    final (order, stopped) = await _liveOrder(ref, quote, l10n, generation, isActive);
    if (order == null) return stopped!;
    if (!isActive()) return const SwapConfirmDropped();

    final fee = _sendsDeposit(quote, ref.read(swapPreflightProvider))
        ? ref.read(swapDepositFeeProvider((account, quote.amountIn))).requireValue
        : null;
    final swaps = ref.read(activeSwapProvider.notifier);
    final ticket = swaps.ticket;
    String? txHash;
    if (fee != null) {
      final (hash, failed) = await _sendDeposit(ref, order, fee, generation, isActive);
      if (hash == null) return failed!;
      txHash = hash;
    }
    // The deposit is out, so the swap is followed even if the review is gone,
    // unless the wallet logged out or moved on meanwhile.
    final followed = swaps.start(
      ActiveSwap(
        order: order,
        accountId: account.accountId,
        accountName: account.name,
        startedAt: clock.now(),
        depositByHand: fee == null,
        depositTxHash: txHash,
        depositFee: fee,
      ),
      ticket: ticket,
    );
    return followed ? const SwapConfirmed() : const SwapConfirmDropped();
  }

  /// A live order at least as good as [quote], or why there is none. A live
  /// order is kept until close to its deadline, so a retry reuses its deposit
  /// address, unless the service was rebuilt meanwhile: the fresh service
  /// then checks the quote's QTC token itself, and an answer the old service
  /// was still owed is discarded.
  Future<(SwapOrder?, SwapConfirmOutcome?)> _liveOrder(
    WidgetRef ref,
    SwapQuote quote,
    AppLocalizations l10n,
    int generation,
    bool Function() isActive,
  ) async {
    final kept = _order;
    if (kept != null && kept.quote.deadline.isAfter(clock.now().add(SwapService.minimumDepositLead))) {
      return (kept, null);
    }
    try {
      final order = await ref.read(swapServiceProvider).createSwap(quote);
      final stale = await _stale(ref, generation, isActive);
      if (stale != null) return (null, stale);
      _order = order;
      final live = order.quote;
      if (live.minAmountOut >= quote.minAmountOut && live.amountIn <= quote.amountIn) return (order, null);
      return (null, SwapTermsChanged(live));
    } catch (e) {
      quantusPrint('Swap create failed: $e');
      return (null, isActive() ? SwapQuoteRefused(describeSwapError(l10n, e)) : const SwapConfirmDropped());
    }
  }

  /// Whether a confirmation started under [generation] may go on: the review
  /// is there, nothing was rebuilt since, and the location, once any refresh
  /// in flight has answered, still allows swaps.
  Future<bool> _proceeds(WidgetRef ref, int generation, bool Function() isActive) async {
    if (!isActive()) return false;
    await ref.read(remoteConfigProvider.notifier).settled;
    return isActive() && generation == _generation && ref.read(remoteConfigProvider).swapAvailable;
  }

  /// Why a confirmation started under [generation] may not go on; null when
  /// it may.
  Future<SwapConfirmOutcome?> _stale(WidgetRef ref, int generation, bool Function() isActive) async {
    if (await _proceeds(ref, generation, isActive)) return null;
    if (!isActive()) return const SwapConfirmDropped();
    return ref.read(remoteConfigProvider).swapAvailable ? const SwapListingChanged() : const SwapNotAllowed();
  }

  /// Sends the quoted QTC into the deposit address: its hash, or why nothing
  /// was sent. Once the owner has approved, the location is checked afresh,
  /// since the prompt can hide a move elsewhere; the deposit goes out only
  /// on an allowance that postdates it.
  Future<(String?, SwapConfirmOutcome?)> _sendDeposit(
    WidgetRef ref,
    SwapOrder order,
    BigInt fee,
    int generation,
    bool Function() isActive,
  ) async {
    final stale = await _stale(ref, generation, isActive);
    if (stale != null) return (null, stale);
    try {
      final service = ref.read(swapServiceProvider);
      final hash = await RegularSendStrategy(account: account).submitLocal(
        ref,
        recipient: order.depositAddress,
        amount: order.quote.amountIn,
        networkFee: fee,
        proceed: () async {
          if (!isActive()) return false;
          await ref.read(remoteConfigProvider.notifier).syncConfig();
          return _proceeds(ref, generation, isActive);
        },
      );
      if (hash == null) {
        final stale = await _stale(ref, generation, isActive);
        return (null, stale ?? const SwapApprovalRequired());
      }
      unawaited(
        service.submitDeposit(order, hash).catchError((Object e) => quantusPrint('Swap deposit submit failed: $e')),
      );
      return (hash, null);
    } catch (e) {
      quantusPrint('Swap deposit transfer failed: $e');
      return (null, isActive() ? const SwapDepositFailed() : const SwapConfirmDropped());
    }
  }
}
