import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/status_item_swaps.dart';
import 'package:quantus_desktop_wallet/providers/swaps_in_progress_provider.dart';
import 'package:quantus_desktop_wallet/utils/swap_words.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/swap/swap_progress.dart';

/// What the menu bar icon says of the swaps on their way with 1Click, in the
/// app's language: the step the newest is on and how many more there are,
/// and each with its steps, as its row names them. A deposit that came short
/// is not on its way: its row says so, and it waits only for its refund.
final statusItemSwapsProvider = Provider<StatusItemSwaps>((ref) {
  final l10n = ref.watch(l10nProvider);
  final fmt = ref.watch(numberFormattingServiceProvider);
  final preflight = ref.watch(swapPreflightProvider) != null;
  final now = clock.now();
  final swaps = [
    for (final swap in ref.watch(swapsInProgressProvider))
      if (swapProgressViewOf(swap, now) == SwapProgressView.inProgress) _listed(l10n, fmt, swap, preflight: preflight),
  ];
  if (swaps.isEmpty) return StatusItemSwaps.none;
  final step = swaps.last.current + 1;
  final more = swaps.length - 1;
  return StatusItemSwaps(
    title: more == 0
        ? l10n.desktopStatusItemSwap(step, swapStepCount)
        : l10n.desktopStatusItemSwapAndMore(step, swapStepCount, more),
    swaps: swaps,
  );
});

StatusItemSwap _listed(AppLocalizations l10n, NumberFormattingService fmt, ActiveSwap swap, {required bool preflight}) {
  final (:amount, :foreignAmount, :network, what: _) = swapAmountWords(l10n, fmt, swap);
  final (:steps, :current) = swapStepWords(l10n, swap, preflight: preflight);
  return StatusItemSwap(
    swapId: swap.id,
    accountId: swap.accountId,
    label: l10n.desktopStatusItemSwapFor(amount, foreignAmount, network),
    steps: steps,
    current: current,
  );
}
