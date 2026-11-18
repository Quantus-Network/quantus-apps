/// Runs steps one at a time, each after the steps added before it have
/// finished, so a step sees what the earlier ones did.
class SerialQueue {
  /// The last step added, finished whether it worked or not.
  Future<void> _last = Future.value();

  /// Runs [step] once the steps added before it have finished. Its result,
  /// or its error, reaches only the returned future; the queue goes on.
  Future<T> run<T>(Future<T> Function() step) {
    final result = _last.then((_) => step());
    _last = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}
