// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:typed_data' as _i5;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i3;

import '../types/pallet_utility/pallet/call.dart' as _i7;
import '../types/quantus_runtime/origin_caller.dart' as _i8;
import '../types/quantus_runtime/runtime_call.dart' as _i6;
import '../types/sp_core/crypto/account_id32.dart' as _i2;
import '../types/sp_weights/weight_v2/weight.dart' as _i9;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.AccountId32, dynamic> _knownDerivatives = const _i1.StorageMap<_i2.AccountId32, dynamic>(
    prefix: 'Utility',
    storage: 'KnownDerivatives',
    valueCodec: _i3.NullCodec.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  /// Derivative pseudonym accounts that have been used with [`Pallet::as_derivative`] at least
  /// once and have therefore been revealed to the wormhole soundness counter.
  _i4.Future<dynamic> knownDerivatives(_i2.AccountId32 key1, {_i1.BlockHash? at}) async {
    final hashedKey = _knownDerivatives.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _knownDerivatives.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Derivative pseudonym accounts that have been used with [`Pallet::as_derivative`] at least
  /// once and have therefore been revealed to the wormhole soundness counter.
  _i4.Future<List<dynamic>> multiKnownDerivatives(List<_i2.AccountId32> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _knownDerivatives.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _knownDerivatives.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `knownDerivatives`.
  _i5.Uint8List knownDerivativesKey(_i2.AccountId32 key1) {
    final hashedKey = _knownDerivatives.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `knownDerivatives`.
  _i5.Uint8List knownDerivativesMapPrefix() {
    final hashedKey = _knownDerivatives.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Send a batch of dispatch calls.
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
  /// This will return `Ok` in all circumstances. To determine the success of the batch, an
  /// event is deposited. If a call failed and the batch was interrupted, then the
  /// `BatchInterrupted` event is deposited, along with the number of successful calls made
  /// and the error of the failed call. If all were successful, then the `BatchCompleted`
  /// event is deposited.
  _i6.Utility batch({required List<_i6.RuntimeCall> calls}) {
    return _i6.Utility(_i7.Batch(calls: calls));
  }

  /// Send a call through an indexed pseudonym of the sender.
  ///
  /// Filter from origin are passed along. The call will be dispatched with an origin which
  /// use the same filter as the origin of this call.
  ///
  /// NOTE: If you need to ensure that any account-based filtering is not honored (i.e.
  /// because you expect `proxy` to have been used prior in the call stack and you do not want
  /// the call restrictions to apply to any sub-accounts), then use `as_multi_threshold_1`
  /// in the Multisig pallet instead.
  ///
  /// NOTE: Prior to version *12, this was called `as_limited_sub`.
  ///
  /// The dispatch origin for this call must be _Signed_.
  _i6.Utility asDerivative({required int index, required _i6.RuntimeCall call}) {
    return _i6.Utility(_i7.AsDerivative(index: index, call: call));
  }

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
  _i6.Utility batchAll({required List<_i6.RuntimeCall> calls}) {
    return _i6.Utility(_i7.BatchAll(calls: calls));
  }

  /// Dispatches a function call with a provided origin.
  ///
  /// The dispatch origin for this call must be _Root_.
  ///
  /// ## Complexity
  /// - O(1).
  _i6.Utility dispatchAs({required _i8.OriginCaller asOrigin, required _i6.RuntimeCall call}) {
    return _i6.Utility(_i7.DispatchAs(asOrigin: asOrigin, call: call));
  }

  /// Send a batch of dispatch calls.
  /// Unlike `batch`, it allows errors and won't interrupt.
  ///
  /// May be called from any origin except `None`.
  ///
  /// - `calls`: The calls to be dispatched from the same origin. The number of call must not
  ///  exceed the constant: `batched_calls_limit` (available in constant metadata).
  ///
  /// If origin is root then the calls are dispatch without checking origin filter. (This
  /// includes bypassing `frame_system::Config::BaseCallFilter`).
  ///
  /// ## Complexity
  /// - O(C) where C is the number of calls to be batched.
  _i6.Utility forceBatch({required List<_i6.RuntimeCall> calls}) {
    return _i6.Utility(_i7.ForceBatch(calls: calls));
  }

  /// Dispatch a function call with a specified weight.
  ///
  /// This function does not check the weight of the call, and instead allows the
  /// Root origin to specify the weight of the call.
  ///
  /// The dispatch origin for this call must be _Root_.
  _i6.Utility withWeight({required _i6.RuntimeCall call, required _i9.Weight weight}) {
    return _i6.Utility(_i7.WithWeight(call: call, weight: weight));
  }

  /// Dispatch a fallback call in the event the main call fails to execute.
  /// May be called from any origin except `None`.
  ///
  /// This function first attempts to dispatch the `main` call.
  /// If the `main` call fails, the `fallback` is attemted.
  /// if the fallback is successfully dispatched, the weights of both calls
  /// are accumulated and an event containing the main call error is deposited.
  ///
  /// In the event of a fallback failure the whole call fails
  /// with the weights returned.
  ///
  /// - `main`: The main call to be dispatched. This is the primary action to execute.
  /// - `fallback`: The fallback call to be dispatched in case the `main` call fails.
  ///
  /// ## Dispatch Logic
  /// - If the origin is `root`, both the main and fallback calls are executed without
  ///  applying any origin filters.
  /// - If the origin is not `root`, the origin filter is applied to both the `main` and
  ///  `fallback` calls.
  ///
  /// ## Use Case
  /// - Some use cases might involve submitting a `batch` type call in either main, fallback
  ///  or both.
  _i6.Utility ifElse({required _i6.RuntimeCall main, required _i6.RuntimeCall fallback}) {
    return _i6.Utility(_i7.IfElse(main: main, fallback: fallback));
  }

  /// Dispatches a function call with a provided origin.
  ///
  /// Almost the same as [`Pallet::dispatch_as`] but forwards any error of the inner call.
  ///
  /// The dispatch origin for this call must be _Root_.
  _i6.Utility dispatchAsFallible({required _i8.OriginCaller asOrigin, required _i6.RuntimeCall call}) {
    return _i6.Utility(_i7.DispatchAsFallible(asOrigin: asOrigin, call: call));
  }
}

class Constants {
  Constants();

  /// The limit on the number of batched calls.
  final int batchedCallsLimit = 10922;
}
