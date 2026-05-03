import 'dart:async';

import 'package:flutter/foundation.dart';

/// Delays execution of [run] until [delay] has elapsed with no new calls.
///
/// Typical usage — debounce a network call triggered by text input:
/// ```dart
/// final _debouncer = Debouncer(delay: const Duration(milliseconds: 500));
///
/// void _onChanged(String value) {
///   _debouncer.run(() => _fetchSomething(value));
/// }
///
/// @override
/// void dispose() {
///   _debouncer.cancel();
///   super.dispose();
/// }
/// ```
class Debouncer {
  final Duration delay;

  Timer? _timer;

  Debouncer({required this.delay});

  /// Schedules [action] to run after [delay].
  ///
  /// If called again before the timer fires, the previous call is discarded
  /// and the timer resets.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any pending action without executing it.
  ///
  /// Call this in [State.dispose] to avoid callbacks firing on unmounted widgets.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether a call is currently pending.
  bool get isPending => _timer?.isActive ?? false;
}
