// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The pallet's dispatchable functions ([`Call`]s).
///
/// Dispatchable functions allows users to interact with the pallet and invoke state changes.
/// These functions materialize as "extrinsics", which are often compared to transactions.
/// They must always return a `DispatchResult` and be annotated with a weight and call index.
///
/// The [`call_index`] macro is used to explicitly
/// define an index for calls in the [`Call`] enum. This is useful for pallets that may
/// introduce new dispatchables over time. If the order of a dispatchable changes, its index
/// will also change which will break backwards compatibility.
///
/// The [`weight`] macro is used to assign a weight to each call.
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

  Map<String, dynamic> toJson();
}

class $Call {
  const $Call();

  DoSomething doSomething({required int something}) {
    return DoSomething(something: something);
  }

  CauseError causeError() {
    return CauseError();
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return DoSomething._decode(input);
      case 1:
        return const CauseError();
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Call value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case DoSomething:
        (value as DoSomething).encodeTo(output);
        break;
      case CauseError:
        (value as CauseError).encodeTo(output);
        break;
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case DoSomething:
        return (value as DoSomething)._sizeHint();
      case CauseError:
        return 1;
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// An example dispatchable that takes a single u32 value as a parameter, writes the value
/// to storage and emits an event.
///
/// It checks that the _origin_ for this call is _Signed_ and returns a dispatch
/// error if it isn't. Learn more about origins here: <https://docs.substrate.io/build/origins/>
class DoSomething extends Call {
  const DoSomething({required this.something});

  factory DoSomething._decode(_i1.Input input) {
    return DoSomething(something: _i1.U32Codec.codec.decode(input));
  }

  /// u32
  final int something;

  @override
  Map<String, Map<String, int>> toJson() => {
        'do_something': {'something': something}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(something);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      something,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is DoSomething && other.something == something;

  @override
  int get hashCode => something.hashCode;
}

/// An example dispatchable that may throw a custom error.
///
/// It checks that the caller is a signed origin and reads the current value from the
/// `Something` storage item. If a current value exists, it is incremented by 1 and then
/// written back to storage.
///
/// ## Errors
///
/// The function will return an error under the following conditions:
///
/// - If no value has been set ([`Error::NoneValue`])
/// - If incrementing the value in storage causes an arithmetic overflow
///  ([`Error::StorageOverflow`])
class CauseError extends Call {
  const CauseError();

  @override
  Map<String, dynamic> toJson() => {'cause_error': null};

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
  }

  @override
  bool operator ==(Object other) => other is CauseError;

  @override
  int get hashCode => runtimeType.hashCode;
}
