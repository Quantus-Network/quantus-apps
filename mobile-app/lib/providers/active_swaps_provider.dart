import 'dart:async';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// The swaps being followed, in order of starting, kept on the device so
/// they survive a restart and polled through 1Click's status endpoint until
/// each settles. One poll loop serves them all: every interval each
/// unsettled swap is polled in turn, and an answer merges into that swap as
/// it is by then. A poll that fails is recorded on its swap and tried again
/// at the next interval; the error leaves it once a poll succeeds.
final activeSwapsProvider = NotifierProvider<ActiveSwapsNotifier, List<ActiveSwap>>(ActiveSwapsNotifier.new);

/// The followed swap with [id], or null once it was put away.
final activeSwapProvider = Provider.family<ActiveSwap?, String>(
  (ref, id) => ref.watch(activeSwapsProvider.select((swaps) => swaps.firstWhereOrNull((s) => s.id == id))),
);

class ActiveSwapsNotifier extends Notifier<List<ActiveSwap>> {
  /// The most swaps followed at once: starting another drops the oldest
  /// settled one, and the review refuses when none is settled.
  static const maxFollowed = 10;

  Timer? _timer;
  Future<void>? _inFlight;
  final _tickets = <Object>{};

  @override
  List<ActiveSwap> build() {
    ref.onDispose(() => _timer?.cancel());
    final swaps = ref.watch(settingsServiceProvider).getActiveSwaps();
    _schedule(swaps);
    return swaps;
  }

  /// Whether no more swaps can start until one settles.
  bool get full => state.where((s) => !s.isFinal).length >= maxFollowed;

  /// Taken before a deposit goes out: [start] follows a swap on it only
  /// while the ticket stands, and a logout voids every ticket, so a deposit
  /// that lands after the wallet logged out is not followed.
  Object ticket() {
    final ticket = Object();
    _tickets.add(ticket);
    return ticket;
  }

  /// Follows [swap], in place of a followed swap with its id; not when
  /// [ticket] has lapsed. Beyond [maxFollowed] the oldest settled swap goes.
  bool start(ActiveSwap swap, {Object? ticket}) {
    if (ticket != null && !_tickets.remove(ticket)) {
      quantusPrint('Swap deposit to ${swap.order.depositAddress} landed after the wallet logged out, not followed');
      return false;
    }
    final settled = state.firstWhereOrNull((s) => s.isFinal);
    if (state.length >= maxFollowed && settled != null) unawaited(remove(settled.id));
    _set(swap);
    _schedule(state);
    return true;
  }

  /// Puts the swap with [id] away. Once it has settled it is done with;
  /// before that the user stops following it, and it settles on its own.
  Future<void> remove(String id) {
    state = [
      for (final s in state)
        if (s.id != id) s,
    ];
    _schedule(state);
    return ref.read(settingsServiceProvider).removeActiveSwap(id);
  }

  /// Forgets every swap and voids every ticket, at logout.
  Future<void> clearAll() {
    _tickets.clear();
    _timer?.cancel();
    state = const [];
    return ref.read(settingsServiceProvider).clearActiveSwaps();
  }

  /// Records that the user has sent the deposit of the swap with [id] by
  /// hand; the swap is then followed as a sent one.
  void markDepositSent(String id) {
    final swap = _find(id);
    if (swap == null) throw StateError('No followed swap $id to mark sent');
    _set(swap.withDepositSent());
  }

  /// Polls every unsettled swap now instead of at the next interval, or
  /// joins the poll in flight.
  Future<void> refresh() {
    _timer?.cancel();
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    late final Future<void> poll;
    poll = _pollAll().whenComplete(() {
      if (identical(_inFlight, poll)) _inFlight = null;
    });
    return _inFlight = poll;
  }

  ActiveSwap? _find(String id) => state.firstWhereOrNull((s) => s.id == id);

  void _set(ActiveSwap swap) {
    final known = _find(swap.id) != null;
    state = known ? [for (final s in state) s.id == swap.id ? swap : s] : [...state, swap];
    if (swap.simulated) return;
    unawaited(
      ref
          .read(settingsServiceProvider)
          .saveActiveSwap(swap)
          .catchError((Object e) => quantusPrint('Active swap save failed: $e')),
    );
  }

  static bool _polled(ActiveSwap swap) => !swap.simulated && !swap.isFinal;

  void _schedule(List<ActiveSwap> swaps) {
    _timer?.cancel();
    if (!swaps.any(_polled)) return;
    _timer = Timer(SwapService.statusPollInterval, refresh);
  }

  /// Polls each unsettled swap in turn and merges the answer into the swap
  /// as it is by then, so a deposit marked sent while the request was out
  /// stays sent; a swap put away meanwhile is left alone.
  Future<void> _pollAll() async {
    for (final swap in state.where(_polled).toList()) {
      try {
        final order = await ref.read(swapServiceProvider).getSwapStatus(swap.order);
        _merge(swap.id, (latest) => latest.withOrder(order, now: clock.now()));
      } catch (e) {
        quantusPrint('Swap status poll failed: $e');
        _merge(swap.id, (latest) => latest.withPollError(describeSwapError(ref.read(l10nProvider), e)));
      }
    }
    _schedule(state);
  }

  void _merge(String id, ActiveSwap Function(ActiveSwap latest) update) {
    final latest = _find(id);
    if (latest != null) _set(update(latest));
  }
}

/// The time, once a second while any followed swap is still running, so
/// the clocks on the swaps advance; once otherwise.
final swapClockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final running = ref.watch(activeSwapsProvider.select((swaps) => swaps.any((s) => s.settledAt == null)));
  final controller = StreamController<DateTime>();
  ref.onDispose(controller.close);
  controller.add(clock.now());
  if (running) {
    final timer = Timer.periodic(const Duration(seconds: 1), (_) => controller.add(clock.now()));
    ref.onDispose(timer.cancel);
  }
  return controller.stream;
});
