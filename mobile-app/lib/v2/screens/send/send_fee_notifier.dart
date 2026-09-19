import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

/// Latest chain fee of the active send flow. The first query runs at once and
/// gates Review; later ones are debounced and only ever refine the value. A
/// result older than the one shown is dropped, a failure never removes a fee
/// that is already known, and the state is [SendFeeState.settled] only once
/// the newest request has landed.
class SendFeeNotifier extends Notifier<SendFeeState> {
  static const debounce = Duration(milliseconds: 500);

  Timer? _timer;
  Future<SendFee> Function()? _lastFetch;
  final _inFlight = <int>{};
  int _issued = 0;
  int _applied = 0;

  @override
  SendFeeState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SendFeeState(pending: true);
  }

  void reset() {
    _timer?.cancel();
    _lastFetch = null;
    _inFlight.clear();
    _applied = _issued;
    state = const SendFeeState(pending: true);
  }

  /// Runs [fetch] now when [immediate], or when nothing is known yet and no
  /// query is in flight; otherwise [debounce] after the last call. Safe to
  /// call from any widget lifecycle: nothing is published synchronously.
  void request(Future<SendFee> Function() fetch, {bool immediate = false}) {
    _timer?.cancel();
    _lastFetch = fetch;
    _publishPending();
    if (immediate || (state.fee == null && _inFlight.isEmpty)) {
      _run(fetch);
    } else {
      _timer = Timer(debounce, () => _run(fetch));
    }
  }

  /// Re-runs the latest request now.
  void retry() {
    final fetch = _lastFetch;
    if (fetch == null) throw StateError('No fee request to retry');
    _timer?.cancel();
    _publishPending();
    _run(fetch);
  }

  /// Riverpod refuses provider writes while the tree is building, and a
  /// request may come from initState, so the pending flag is published a
  /// microtask later. Scheduled before the run starts it lands ahead of any
  /// result, and once nothing is queued or in flight it does nothing.
  void _publishPending() {
    scheduleMicrotask(() {
      if (!ref.mounted || (_inFlight.isEmpty && !(_timer?.isActive ?? false))) return;
      state = state.copyWith(pending: true, failed: false);
    });
  }

  bool _isNewest(int seq) => seq == _issued && !(_timer?.isActive ?? false);

  Future<void> _run(Future<SendFee> Function() fetch) async {
    final seq = ++_issued;
    _inFlight.add(seq);
    try {
      final fee = await fetch();
      if (!ref.mounted || seq <= _applied) return;
      _applied = seq;
      state = SendFeeState(fee: fee, pending: !_isNewest(seq));
    } catch (e, st) {
      quantusPrint('Send fee fetch failed: $e\n$st');
      if (!ref.mounted || seq <= _applied || !_isNewest(seq)) return;
      state = SendFeeState(fee: state.fee, failed: true);
    } finally {
      _inFlight.remove(seq);
    }
  }
}

final sendFeeProvider = NotifierProvider<SendFeeNotifier, SendFeeState>(SendFeeNotifier.new);
