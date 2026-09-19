import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

/// Latest chain fee of the active send flow. The first query runs at once and
/// gates Review; later ones are debounced and only ever refine the value: a
/// result older than the one shown is dropped, and a failure never removes a
/// fee that is already known.
class SendFeeNotifier extends Notifier<AsyncValue<SendFee>> {
  static const debounce = Duration(milliseconds: 500);

  Timer? _timer;
  final _inFlight = <int>{};
  int _issued = 0;
  int _applied = 0;

  @override
  AsyncValue<SendFee> build() {
    ref.onDispose(() => _timer?.cancel());
    return const AsyncValue.loading();
  }

  void reset() {
    _timer?.cancel();
    _inFlight.clear();
    _applied = _issued;
    state = const AsyncValue.loading();
  }

  void request(Future<SendFee> Function() fetch) {
    _timer?.cancel();
    if (state.hasValue || _inFlight.isNotEmpty) {
      _timer = Timer(debounce, () => _run(fetch));
    } else {
      _run(fetch);
    }
  }

  void retry(Future<SendFee> Function() fetch) {
    _timer?.cancel();
    _run(fetch);
  }

  Future<void> _run(Future<SendFee> Function() fetch) async {
    final seq = ++_issued;
    _inFlight.add(seq);
    try {
      final fee = await fetch();
      if (ref.mounted && seq > _applied) {
        _applied = seq;
        state = AsyncValue.data(fee);
      }
    } catch (e, st) {
      quantusPrint('Send fee fetch failed: $e\n$st');
      if (ref.mounted && seq > _applied && !state.hasValue) state = AsyncValue.error(e, st);
    } finally {
      _inFlight.remove(seq);
    }
  }
}

final sendFeeProvider = NotifierProvider<SendFeeNotifier, AsyncValue<SendFee>>(SendFeeNotifier.new);
