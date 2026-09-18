// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

abstract class LaunchAnchor {
  const LaunchAnchor();

  factory LaunchAnchor.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $LaunchAnchorCodec codec = $LaunchAnchorCodec();

  static const $LaunchAnchor values = $LaunchAnchor();

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

class $LaunchAnchor {
  const $LaunchAnchor();

  Pending pending() {
    return Pending();
  }

  Anchored anchored(BigInt value0) {
    return Anchored(value0);
  }
}

class $LaunchAnchorCodec with _i1.Codec<LaunchAnchor> {
  const $LaunchAnchorCodec();

  @override
  LaunchAnchor decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return const Pending();
      case 1:
        return Anchored._decode(input);
      default:
        throw Exception('LaunchAnchor: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(LaunchAnchor value, _i1.Output output) {
    switch (value.runtimeType) {
      case Pending:
        (value as Pending).encodeTo(output);
        break;
      case Anchored:
        (value as Anchored).encodeTo(output);
        break;
      default:
        throw Exception('LaunchAnchor: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(LaunchAnchor value) {
    switch (value.runtimeType) {
      case Pending:
        return 1;
      case Anchored:
        return (value as Anchored)._sizeHint();
      default:
        throw Exception('LaunchAnchor: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class Pending extends LaunchAnchor {
  const Pending();

  @override
  Map<String, dynamic> toJson() => {'Pending': null};

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
  }

  @override
  bool operator ==(Object other) => other is Pending;

  @override
  int get hashCode => runtimeType.hashCode;
}

class Anchored extends LaunchAnchor {
  const Anchored(this.value0);

  factory Anchored._decode(_i1.Input input) {
    return Anchored(_i1.U64Codec.codec.decode(input));
  }

  /// Moment
  final BigInt value0;

  @override
  Map<String, BigInt> toJson() => {'Anchored': value0};

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    _i1.U64Codec.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Anchored && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}
