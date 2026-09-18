// ignore_for_file: no_leading_underscores_for_library_prefixes
import '../types/pallet_utility/pallet/call.dart' as _i2;
import '../types/quantus_runtime/runtime_call.dart' as _i1;

class Txs {
  const Txs();

  /// Send a batch of dispatch calls and atomically execute them.
  /// The whole transaction will rollback and fail if any of the calls failed.
  ///
  /// May be called from any origin except `None`.
  ///
  /// - `calls`: The calls to be dispatched from the same origin. The number of call must not
  ///  exceed the constant: `batched_calls_limit` (available in constant metadata).
  ///
  /// If origin is root then the calls are dispatched without checking origin filter. (This
  /// includes bypassing `frame_system::Config::BaseCallFilter`).
  ///
  /// ## Complexity
  /// - O(C) where C is the number of calls to be batched.
  ///
  /// Call index 2 is preserved from the upstream utility pallet so existing
  /// `batch_all` encodings keep decoding after the other combinators were removed.
  _i1.Utility batchAll({required List<_i1.RuntimeCall> calls}) {
    return _i1.Utility(_i2.BatchAll(calls: calls));
  }
}

class Constants {
  Constants();

  /// The limit on the number of batched calls.
  final int batchedCallsLimit = 10922;
}
