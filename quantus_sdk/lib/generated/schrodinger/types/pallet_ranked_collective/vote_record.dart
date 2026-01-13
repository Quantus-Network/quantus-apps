// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

abstract class VoteRecord {
  const VoteRecord();

  factory VoteRecord.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $VoteRecordCodec codec = $VoteRecordCodec();

  static const $VoteRecord values = $VoteRecord();

  _i2.Uint8List encode() {
    final output = _i1.ByteOutput(codec.sizeHint(this));
    codec.encodeTo(this, output);
    return output.toBytes();
  }

  int sizeHint() {
    return codec.sizeHint(this);
  }

  Map<String, int> toJson();
}

class $VoteRecord {
  const $VoteRecord();

  Aye aye(int value0) {
    return Aye(value0);
  }

  Nay nay(int value0) {
    return Nay(value0);
  }
}

class $VoteRecordCodec with _i1.Codec<VoteRecord> {
  const $VoteRecordCodec();

  @override
  VoteRecord decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Aye._decode(input);
      case 1:
        return Nay._decode(input);
      default:
        throw Exception('VoteRecord: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    VoteRecord value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case Aye:
        (value as Aye).encodeTo(output);
        break;
      case Nay:
        (value as Nay).encodeTo(output);
        break;
      default:
        throw Exception(
            'VoteRecord: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(VoteRecord value) {
    switch (value.runtimeType) {
      case Aye:
        return (value as Aye)._sizeHint();
      case Nay:
        return (value as Nay)._sizeHint();
      default:
        throw Exception(
            'VoteRecord: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class Aye extends VoteRecord {
  const Aye(this.value0);

  factory Aye._decode(_i1.Input input) {
    return Aye(_i1.U32Codec.codec.decode(input));
  }

  /// Votes
  final int value0;

  @override
  Map<String, int> toJson() => {'Aye': value0};

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
      other is Aye && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Nay extends VoteRecord {
  const Nay(this.value0);

  factory Nay._decode(_i1.Input input) {
    return Nay(_i1.U32Codec.codec.decode(input));
  }

  /// Votes
  final int value0;

  @override
  Map<String, int> toJson() => {'Nay': value0};

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
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
      other is Nay && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}
