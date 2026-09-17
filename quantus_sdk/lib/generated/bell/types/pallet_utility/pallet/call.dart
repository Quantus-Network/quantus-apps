// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../quantus_runtime/runtime_call.dart' as _i3;

/// Contains a variant per dispatchable extrinsic that this pallet has.
abstract class Call {
  const Call();

  factory Call.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $CallCodec codec = $CallCodec();

  static const $Call values = $Call();

  _i2.Uint8List encode() {
    final output = _i1.ByteOutput(codec.sizeHint(this));
    codec.encodeTo(this, output);
    return output.toBytes();
  }

  int sizeHint() {
    return codec.sizeHint(this);
  }

  Map<String, Map<String, List<Map<String, Map<String, dynamic>>>>> toJson();
}

class $Call {
  const $Call();

  BatchAll batchAll({required List<_i3.RuntimeCall> calls}) {
    return BatchAll(calls: calls);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 2:
        return BatchAll._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Call value, _i1.Output output) {
    switch (value.runtimeType) {
      case BatchAll:
        (value as BatchAll).encodeTo(output);
        break;
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case BatchAll:
        return (value as BatchAll)._sizeHint();
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
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
///
/// Call index 2 is preserved from the upstream utility pallet so existing
/// `batch_all` encodings keep decoding after the other combinators were removed.
class BatchAll extends Call {
  const BatchAll({required this.calls});

  factory BatchAll._decode(_i1.Input input) {
    return BatchAll(calls: const _i1.SequenceCodec<_i3.RuntimeCall>(_i3.RuntimeCall.codec).decode(input));
  }

  /// Vec<<T as Config>::RuntimeCall>
  final List<_i3.RuntimeCall> calls;

  @override
  Map<String, Map<String, List<Map<String, Map<String, dynamic>>>>> toJson() => {
    'batch_all': {'calls': calls.map((value) => value.toJson()).toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i1.SequenceCodec<_i3.RuntimeCall>(_i3.RuntimeCall.codec).sizeHint(calls);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    const _i1.SequenceCodec<_i3.RuntimeCall>(_i3.RuntimeCall.codec).encodeTo(calls, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is BatchAll && _i4.listsEqual(other.calls, calls);

  @override
  int get hashCode => calls.hashCode;
}
