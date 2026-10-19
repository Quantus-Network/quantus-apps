import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// The swap being followed, kept on the device so it survives a restart and
/// polled through 1Click's status endpoint until it settles. A poll that
/// fails is recorded on the swap and tried again at the next interval; the
/// error leaves it once a poll succeeds. One poll runs at a time, so an
/// older answer can never overwrite a newer one.
final activeSwapProvider = NotifierProvider<ActiveSwapNotifier, ActiveSwap?>(ActiveSwapNotifier.new);

class ActiveSwapNotifier extends Notifier<ActiveSwap?> {
  Timer? _poll;
  Future<void>? _inFlight;
  int _generation = 0;

  @override
  ActiveSwap? build() {
    ref.onDispose(() => _poll?.cancel());
    final swap = ref.watch(settingsServiceProvider).getActiveSwap();
    if (swap != null) _schedule(swap);
    return swap;
  }

  /// Taken before a deposit goes out: [start] follows a swap on it only while
  /// nothing was started or cleared since, so a deposit that lands after a
  /// logout, or after the user moved on to another swap, is not followed.
  int get ticket => _generation;

  /// Follows [swap], or leaves things as they are when [ticket] has lapsed.
  bool start(ActiveSwap swap, {int? ticket}) {
    if (ticket != null && ticket != _generation) {
      quantusPrint('Swap deposit to ${swap.order.depositAddress} landed after the wallet moved on, not followed');
      return false;
    }
    _supersede();
    _set(swap);
    _schedule(swap);
    return true;
  }

  /// Puts the swap away. Once it has settled it is done with; before that the
  /// user stops following it, and it settles on its own.
  Future<void> clear() {
    _supersede();
    state = null;
    return ref.read(settingsServiceProvider).clearActiveSwap();
  }

  /// Records that the user has sent a deposit by hand; the swap is then
  /// followed as a sent one.
  void markDepositSent() {
    final current = state;
    if (current == null) throw StateError('No active swap to mark sent');
    _set(current.withDepositSent());
  }

  /// Polls now instead of at the next interval, or joins the poll in flight.
  Future<void> refresh() {
    _poll?.cancel();
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    late final Future<void> poll;
    poll = _refresh().whenComplete(() {
      if (identical(_inFlight, poll)) _inFlight = null;
    });
    return _inFlight = poll;
  }

  /// Disowns the swap being followed: its timer stops and its poll in
  /// flight, if any, is left to answer into the void, so the next swap polls
  /// on its own.
  void _supersede() {
    _generation++;
    _poll?.cancel();
    _inFlight = null;
  }

  void _set(ActiveSwap swap) {
    state = swap;
    if (swap.simulated) return;
    unawaited(
      ref
          .read(settingsServiceProvider)
          .setActiveSwap(swap)
          .catchError((Object e) => quantusPrint('Active swap save failed: $e')),
    );
  }

  void _schedule(ActiveSwap swap) {
    _poll?.cancel();
    if (swap.simulated || swap.isFinal) return;
    _poll = Timer(SwapService.statusPollInterval, refresh);
  }

  /// Polls the swap and merges the answer into the swap as it is by then,
  /// so a deposit marked sent while the request was out stays sent.
  Future<void> _refresh() async {
    final current = state;
    if (current == null || current.simulated || current.isFinal) return;
    final generation = _generation;
    try {
      final order = await ref.read(swapServiceProvider).getSwapStatus(current.order);
      if (generation != _generation) return;
      _set(state!.withOrder(order, now: clock.now()));
    } catch (e) {
      quantusPrint('Swap status poll failed: $e');
      if (generation != _generation) return;
      _set(state!.withPollError(describeSwapError(ref.read(l10nProvider), e)));
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
