import 'dart:async';

/// Runs steps one at a time, each after the steps added before it have
/// finished, so a step sees what the earlier ones did.
class SerialQueue {
  /// Completes when the last step added has finished, whether it worked or
  /// not.
  Future<void> _last = Future.value();

  /// Runs [step] once the steps added before it have finished. Its result,
  /// or its error, reaches only the returned future, and the queue goes on.
  /// The queue does not listen to that future, so an error nobody waits for
  /// is reported as unhandled rather than lost.
  Future<T> run<T>(Future<T> Function() step) {
    final previous = _last;
    final finished = Completer<void>();
    _last = finished.future;
    Future<T> runAfterPrevious() async {
      await previous;
      try {
        return await step();
      } finally {
        finished.complete();
      }
    }

    return runAfterPrevious();
  }
}
