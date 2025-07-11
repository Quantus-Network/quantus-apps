// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../junction/junction.dart' as _i3;

abstract class Junctions {
  const Junctions();

  factory Junctions.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $JunctionsCodec codec = $JunctionsCodec();

  static const $Junctions values = $Junctions();

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

class $Junctions {
  const $Junctions();

  Here here() {
    return Here();
  }

  X1 x1(List<_i3.Junction> value0) {
    return X1(value0);
  }

  X2 x2(List<_i3.Junction> value0) {
    return X2(value0);
  }

  X3 x3(List<_i3.Junction> value0) {
    return X3(value0);
  }

  X4 x4(List<_i3.Junction> value0) {
    return X4(value0);
  }

  X5 x5(List<_i3.Junction> value0) {
    return X5(value0);
  }

  X6 x6(List<_i3.Junction> value0) {
    return X6(value0);
  }

  X7 x7(List<_i3.Junction> value0) {
    return X7(value0);
  }

  X8 x8(List<_i3.Junction> value0) {
    return X8(value0);
  }
}

class $JunctionsCodec with _i1.Codec<Junctions> {
  const $JunctionsCodec();

  @override
  Junctions decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return const Here();
      case 1:
        return X1._decode(input);
      case 2:
        return X2._decode(input);
      case 3:
        return X3._decode(input);
      case 4:
        return X4._decode(input);
      case 5:
        return X5._decode(input);
      case 6:
        return X6._decode(input);
      case 7:
        return X7._decode(input);
      case 8:
        return X8._decode(input);
      default:
        throw Exception('Junctions: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Junctions value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case Here:
        (value as Here).encodeTo(output);
        break;
      case X1:
        (value as X1).encodeTo(output);
        break;
      case X2:
        (value as X2).encodeTo(output);
        break;
      case X3:
        (value as X3).encodeTo(output);
        break;
      case X4:
        (value as X4).encodeTo(output);
        break;
      case X5:
        (value as X5).encodeTo(output);
        break;
      case X6:
        (value as X6).encodeTo(output);
        break;
      case X7:
        (value as X7).encodeTo(output);
        break;
      case X8:
        (value as X8).encodeTo(output);
        break;
      default:
        throw Exception(
            'Junctions: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Junctions value) {
    switch (value.runtimeType) {
      case Here:
        return 1;
      case X1:
        return (value as X1)._sizeHint();
      case X2:
        return (value as X2)._sizeHint();
      case X3:
        return (value as X3)._sizeHint();
      case X4:
        return (value as X4)._sizeHint();
      case X5:
        return (value as X5)._sizeHint();
      case X6:
        return (value as X6)._sizeHint();
      case X7:
        return (value as X7)._sizeHint();
      case X8:
        return (value as X8)._sizeHint();
      default:
        throw Exception(
            'Junctions: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class Here extends Junctions {
  const Here();

  @override
  Map<String, dynamic> toJson() => {'Here': null};

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
  }

  @override
  bool operator ==(Object other) => other is Here;

  @override
  int get hashCode => runtimeType.hashCode;
}

class X1 extends Junctions {
  const X1(this.value0);

  factory X1._decode(_i1.Input input) {
    return X1(const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      1,
    ).decode(input));
  }

  /// Arc<[Junction; 1]>
  final List<_i3.Junction> value0;

  @override
  Map<String, List<Map<String, dynamic>>> toJson() =>
      {'X1': value0.map((value) => value.toJson()).toList()};

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.ArrayCodec<_i3.Junction>(
          _i3.Junction.codec,
          1,
        ).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      1,
    ).encodeTo(
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
      other is X1 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class X2 extends Junctions {
  const X2(this.value0);

  factory X2._decode(_i1.Input input) {
    return X2(const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      2,
    ).decode(input));
  }

  /// Arc<[Junction; 2]>
  final List<_i3.Junction> value0;

  @override
  Map<String, List<Map<String, dynamic>>> toJson() =>
      {'X2': value0.map((value) => value.toJson()).toList()};

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.ArrayCodec<_i3.Junction>(
          _i3.Junction.codec,
          2,
        ).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      2,
    ).encodeTo(
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
      other is X2 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class X3 extends Junctions {
  const X3(this.value0);

  factory X3._decode(_i1.Input input) {
    return X3(const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      3,
    ).decode(input));
  }

  /// Arc<[Junction; 3]>
  final List<_i3.Junction> value0;

  @override
  Map<String, List<Map<String, dynamic>>> toJson() =>
      {'X3': value0.map((value) => value.toJson()).toList()};

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.ArrayCodec<_i3.Junction>(
          _i3.Junction.codec,
          3,
        ).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      3,
    ).encodeTo(
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
      other is X3 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class X4 extends Junctions {
  const X4(this.value0);

  factory X4._decode(_i1.Input input) {
    return X4(const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      4,
    ).decode(input));
  }

  /// Arc<[Junction; 4]>
  final List<_i3.Junction> value0;

  @override
  Map<String, List<Map<String, dynamic>>> toJson() =>
      {'X4': value0.map((value) => value.toJson()).toList()};

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.ArrayCodec<_i3.Junction>(
          _i3.Junction.codec,
          4,
        ).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      4,
      output,
    );
    const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      4,
    ).encodeTo(
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
      other is X4 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class X5 extends Junctions {
  const X5(this.value0);

  factory X5._decode(_i1.Input input) {
    return X5(const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      5,
    ).decode(input));
  }

  /// Arc<[Junction; 5]>
  final List<_i3.Junction> value0;

  @override
  Map<String, List<Map<String, dynamic>>> toJson() =>
      {'X5': value0.map((value) => value.toJson()).toList()};

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.ArrayCodec<_i3.Junction>(
          _i3.Junction.codec,
          5,
        ).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      5,
      output,
    );
    const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      5,
    ).encodeTo(
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
      other is X5 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class X6 extends Junctions {
  const X6(this.value0);

  factory X6._decode(_i1.Input input) {
    return X6(const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      6,
    ).decode(input));
  }

  /// Arc<[Junction; 6]>
  final List<_i3.Junction> value0;

  @override
  Map<String, List<Map<String, dynamic>>> toJson() =>
      {'X6': value0.map((value) => value.toJson()).toList()};

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.ArrayCodec<_i3.Junction>(
          _i3.Junction.codec,
          6,
        ).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      6,
      output,
    );
    const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      6,
    ).encodeTo(
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
      other is X6 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class X7 extends Junctions {
  const X7(this.value0);

  factory X7._decode(_i1.Input input) {
    return X7(const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      7,
    ).decode(input));
  }

  /// Arc<[Junction; 7]>
  final List<_i3.Junction> value0;

  @override
  Map<String, List<Map<String, dynamic>>> toJson() =>
      {'X7': value0.map((value) => value.toJson()).toList()};

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.ArrayCodec<_i3.Junction>(
          _i3.Junction.codec,
          7,
        ).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      7,
      output,
    );
    const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      7,
    ).encodeTo(
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
      other is X7 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class X8 extends Junctions {
  const X8(this.value0);

  factory X8._decode(_i1.Input input) {
    return X8(const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      8,
    ).decode(input));
  }

  /// Arc<[Junction; 8]>
  final List<_i3.Junction> value0;

  @override
  Map<String, List<Map<String, dynamic>>> toJson() =>
      {'X8': value0.map((value) => value.toJson()).toList()};

  int _sizeHint() {
    int size = 1;
    size = size +
        const _i1.ArrayCodec<_i3.Junction>(
          _i3.Junction.codec,
          8,
        ).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      8,
      output,
    );
    const _i1.ArrayCodec<_i3.Junction>(
      _i3.Junction.codec,
      8,
    ).encodeTo(
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
      other is X8 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}
