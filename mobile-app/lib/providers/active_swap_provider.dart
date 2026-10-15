import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/active_swap.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// The swap being followed, kept on the device so it survives a restart and
/// polled through 1Click's status endpoint until it settles. A poll that
/// fails is recorded on the swap and tried again at the next interval; the
/// error leaves it once a poll succeeds.
final activeSwapProvider = NotifierProvider<ActiveSwapNotifier, ActiveSwap?>(ActiveSwapNotifier.new);

class ActiveSwapNotifier extends Notifier<ActiveSwap?> {
  static const storageKey = 'active_swap_v1';

  Timer? _poll;
  int _generation = 0;

  @override
  ActiveSwap? build() {
    ref.onDispose(() => _poll?.cancel());
    final stored = ref.watch(settingsServiceProvider).getString(storageKey);
    if (stored == null) return null;
    final swap = ActiveSwap.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    _schedule(swap);
    return swap;
  }

  void start(ActiveSwap swap) {
    _generation++;
    _set(swap);
    _schedule(swap);
  }

  /// Puts the swap away. Once it has settled it is done with; before that the
  /// user gives up on it.
  Future<void> clear() {
    _generation++;
    _poll?.cancel();
    state = null;
    return ref.read(settingsServiceProvider).remove(storageKey);
  }

  /// Polls now instead of at the next interval.
  Future<void> refresh() {
    _poll?.cancel();
    return _refresh();
  }

  void _set(ActiveSwap swap) {
    state = swap;
    if (swap.simulated) return;
    unawaited(
      ref
          .read(settingsServiceProvider)
          .setString(storageKey, jsonEncode(swap.toJson()))
          .catchError((Object e) => quantusPrint('Active swap save failed: $e')),
    );
  }

  void _schedule(ActiveSwap swap) {
    _poll?.cancel();
    if (swap.simulated || swap.isFinal) return;
    _poll = Timer(SwapService.statusPollInterval, _refresh);
  }

  Future<void> _refresh() async {
    final current = state;
    if (current == null || current.simulated || current.isFinal) return;
    final generation = _generation;
    try {
      final order = await ref.read(swapServiceProvider).getSwapStatus(current.order);
      if (generation != _generation) return;
      _set(current.withOrder(order, now: clock.now()));
    } catch (e) {
      quantusPrint('Swap status poll failed: $e');
      if (generation != _generation) return;
      _set(current.withPollError(describeSwapError(e)));
    }
    final next = state;
    if (next != null) _schedule(next);
  }
}

/// How long the active swap has been running, once a second until it settles.
final swapElapsedProvider = StreamProvider.autoDispose<Duration>((ref) {
  final swap = ref.watch(activeSwapProvider);
  final controller = StreamController<Duration>();
  ref.onDispose(controller.close);
  if (swap == null) return controller.stream;
  controller.add(swap.elapsedAt(clock.now()));
  if (swap.settledAt == null) {
    final timer = Timer.periodic(const Duration(seconds: 1), (_) => controller.add(swap.elapsedAt(clock.now())));
    ref.onDispose(timer.cancel);
  }
  return controller.stream;
});
