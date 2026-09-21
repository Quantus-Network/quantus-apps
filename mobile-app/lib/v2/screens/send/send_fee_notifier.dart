import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

/// Latest chain fee of the active send flow. Requests are numbered and the
/// state is derived from the newest issued, the newest finished and the newest
/// applied, so an older result can neither overwrite a newer fee nor clear a
/// newer failure. Requests come from event handlers only, never from a widget
/// lifecycle, so the state is published synchronously.
class SendFeeNotifier extends Notifier<SendFeeState> {
  static const debounce = Duration(milliseconds: 500);

  Timer? _timer;
  Future<SendFee> Function()? _lastFetch;
  int _issued = 0;
  int _finished = 0;
  bool _finishedFailed = false;
  int _applied = 0;
  SendFee? _fee;

  @override
  SendFeeState build() {
    ref.onDispose(() => _timer?.cancel());
    return const SendFeeState();
  }

  void reset() {
    _timer?.cancel();
    _lastFetch = null;
    _applied = _finished = _issued;
    _finishedFailed = false;
    _fee = null;
    _publish();
  }

  /// Runs [fetch] now when [immediate], or when nothing is known yet and no
  /// query is in flight; otherwise [debounce] after the last call.
  void request(Future<SendFee> Function() fetch, {bool immediate = false}) {
    _timer?.cancel();
    _lastFetch = fetch;
    if (immediate || (_fee == null && _finished == _issued)) {
      _run(fetch);
    } else {
      _timer = Timer(debounce, () => _run(fetch));
      _publish();
    }
  }

  /// Re-runs the latest request now.
  void retry() {
    final fetch = _lastFetch;
    if (fetch == null) throw StateError('No fee request to retry');
    _timer?.cancel();
    _run(fetch);
  }

  Future<void> _run(Future<SendFee> Function() fetch) async {
    final seq = ++_issued;
    _publish();
    try {
      final fee = await fetch();
      if (!ref.mounted) return;
      if (seq > _applied) {
        _applied = seq;
        _fee = fee;
      }
      _finish(seq, failed: false);
    } catch (e, st) {
      quantusPrint('Send fee fetch failed: $e\n$st');
      if (ref.mounted) _finish(seq, failed: true);
    }
  }

  void _finish(int seq, {required bool failed}) {
    if (seq > _finished) {
      _finished = seq;
      _finishedFailed = failed;
    }
    _publish();
  }

  void _publish() {
    final queued = _timer?.isActive ?? false;
    state = SendFeeState(
      fee: _fee,
      pending: queued || _finished < _issued,
      failed: !queued && _finished == _issued && _finishedFailed,
    );
  }
}

final sendFeeProvider = NotifierProvider<SendFeeNotifier, SendFeeState>(SendFeeNotifier.new);
