// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i3;

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

  Map<String, Map<String, List<int>>> toJson();
}

class $Call {
  const $Call();

  VerifyPrivateBatch verifyPrivateBatch({required List<int> proofBytes}) {
    return VerifyPrivateBatch(proofBytes: proofBytes);
  }

  VerifyPublicBatch verifyPublicBatch({required List<int> proofBytes}) {
    return VerifyPublicBatch(proofBytes: proofBytes);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 2:
        return VerifyPrivateBatch._decode(input);
      case 3:
        return VerifyPublicBatch._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Call value, _i1.Output output) {
    switch (value.runtimeType) {
      case VerifyPrivateBatch:
        (value as VerifyPrivateBatch).encodeTo(output);
        break;
      case VerifyPublicBatch:
        (value as VerifyPublicBatch).encodeTo(output);
        break;
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case VerifyPrivateBatch:
        return (value as VerifyPrivateBatch)._sizeHint();
      case VerifyPublicBatch:
        return (value as VerifyPublicBatch)._sizeHint();
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class VerifyPrivateBatch extends Call {
  const VerifyPrivateBatch({required this.proofBytes});

  factory VerifyPrivateBatch._decode(_i1.Input input) {
    return VerifyPrivateBatch(proofBytes: _i1.U8SequenceCodec.codec.decode(input));
  }

  final List<int> proofBytes;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'verify_private_batch': {'proofBytes': proofBytes},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U8SequenceCodec.codec.sizeHint(proofBytes);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    _i1.U8SequenceCodec.codec.encodeTo(proofBytes, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VerifyPrivateBatch && _i3.listsEqual(other.proofBytes, proofBytes);

  @override
  int get hashCode => proofBytes.hashCode;
}

class VerifyPublicBatch extends Call {
  const VerifyPublicBatch({required this.proofBytes});

  factory VerifyPublicBatch._decode(_i1.Input input) {
    return VerifyPublicBatch(proofBytes: _i1.U8SequenceCodec.codec.decode(input));
  }

  final List<int> proofBytes;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'verify_public_batch': {'proofBytes': proofBytes},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U8SequenceCodec.codec.sizeHint(proofBytes);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(3, output);
    _i1.U8SequenceCodec.codec.encodeTo(proofBytes, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VerifyPublicBatch && _i3.listsEqual(other.proofBytes, proofBytes);

  @override
  int get hashCode => proofBytes.hashCode;
}
