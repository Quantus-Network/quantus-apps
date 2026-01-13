// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

abstract class BlockNumberOrTimestamp {
  const BlockNumberOrTimestamp();

  factory BlockNumberOrTimestamp.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $BlockNumberOrTimestampCodec codec =
      $BlockNumberOrTimestampCodec();

  static const $BlockNumberOrTimestamp values = $BlockNumberOrTimestamp();

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

class $BlockNumberOrTimestamp {
  const $BlockNumberOrTimestamp();

  BlockNumber blockNumber(int value0) {
    return BlockNumber(value0);
  }

  Timestamp timestamp(BigInt value0) {
    return Timestamp(value0);
  }
}

class $BlockNumberOrTimestampCodec with _i1.Codec<BlockNumberOrTimestamp> {
  const $BlockNumberOrTimestampCodec();

  @override
  BlockNumberOrTimestamp decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return BlockNumber._decode(input);
      case 1:
        return Timestamp._decode(input);
      default:
        throw Exception(
            'BlockNumberOrTimestamp: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    BlockNumberOrTimestamp value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case BlockNumber:
        (value as BlockNumber).encodeTo(output);
        break;
      case Timestamp:
        (value as Timestamp).encodeTo(output);
        break;
      default:
        throw Exception(
            'BlockNumberOrTimestamp: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(BlockNumberOrTimestamp value) {
    switch (value.runtimeType) {
      case BlockNumber:
        return (value as BlockNumber)._sizeHint();
      case Timestamp:
        return (value as Timestamp)._sizeHint();
      default:
        throw Exception(
            'BlockNumberOrTimestamp: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class BlockNumber extends BlockNumberOrTimestamp {
  const BlockNumber(this.value0);

  factory BlockNumber._decode(_i1.Input input) {
    return BlockNumber(_i1.U32Codec.codec.decode(input));
  }

  /// BlockNumber
  final int value0;

  @override
  Map<String, int> toJson() => {'BlockNumber': value0};

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is BlockNumber && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Timestamp extends BlockNumberOrTimestamp {
  const Timestamp(this.value0);

  factory Timestamp._decode(_i1.Input input) {
    return Timestamp(_i1.U64Codec.codec.decode(input));
  }

  /// Moment
  final BigInt value0;

  @override
  Map<String, BigInt> toJson() => {'Timestamp': value0};

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Timestamp && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}
