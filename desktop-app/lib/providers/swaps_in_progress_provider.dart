import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';

/// The followed swaps in progress now ([ActiveSwap.inProgressAt]), in order of
/// starting: not one that ended, one still awaiting its deposit by hand, or
/// one overdue, which is polled no more. A swap turns overdue with the time
/// alone, nothing about it changing, so the list is read again at that moment.
final swapsInProgressProvider = Provider<List<ActiveSwap>>((ref) {
  final swaps = ref.watch(activeSwapsProvider);
  final now = clock.now();
  final inProgress = [
    for (final swap in swaps)
      if (swap.inProgressAt(now)) swap,
  ];
  DateTime? soonestOverdue;
  for (final swap in inProgress) {
    final overdueFrom = swap.order.quote.deadline.add(ActiveSwap.finishGrace);
    if (soonestOverdue == null || overdueFrom.isBefore(soonestOverdue)) soonestOverdue = overdueFrom;
  }
  if (soonestOverdue != null) {
    // Overdue is strictly after that moment.
    final timer = Timer(soonestOverdue.difference(now) + const Duration(milliseconds: 1), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return inProgress;
});
