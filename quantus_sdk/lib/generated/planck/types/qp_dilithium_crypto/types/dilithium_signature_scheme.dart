// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

import 'dilithium65_signature_with_public.dart' as _i4;
import 'dilithium87_signature_with_public.dart' as _i3;

abstract class DilithiumSignatureScheme {
  const DilithiumSignatureScheme();

  factory DilithiumSignatureScheme.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $DilithiumSignatureSchemeCodec codec = $DilithiumSignatureSchemeCodec();

  static const $DilithiumSignatureScheme values = $DilithiumSignatureScheme();

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

class $DilithiumSignatureScheme {
  const $DilithiumSignatureScheme();

  Dilithium87 dilithium87(_i3.Dilithium87SignatureWithPublic value0) {
    return Dilithium87(value0);
  }

  Dilithium65 dilithium65(_i4.Dilithium65SignatureWithPublic value0) {
    return Dilithium65(value0);
  }
}

class $DilithiumSignatureSchemeCodec with _i1.Codec<DilithiumSignatureScheme> {
  const $DilithiumSignatureSchemeCodec();

  @override
  DilithiumSignatureScheme decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Dilithium87._decode(input);
      case 1:
        return Dilithium65._decode(input);
      default:
        throw Exception('DilithiumSignatureScheme: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(DilithiumSignatureScheme value, _i1.Output output) {
    switch (value.runtimeType) {
      case Dilithium87:
        (value as Dilithium87).encodeTo(output);
        break;
      case Dilithium65:
        (value as Dilithium65).encodeTo(output);
        break;
      default:
        throw Exception('DilithiumSignatureScheme: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(DilithiumSignatureScheme value) {
    switch (value.runtimeType) {
      case Dilithium87:
        return (value as Dilithium87)._sizeHint();
      case Dilithium65:
        return (value as Dilithium65)._sizeHint();
      default:
        throw Exception('DilithiumSignatureScheme: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class Dilithium87 extends DilithiumSignatureScheme {
  const Dilithium87(this.value0);

  factory Dilithium87._decode(_i1.Input input) {
    return Dilithium87(_i3.Dilithium87SignatureWithPublic.codec.decode(input));
  }

  /// Dilithium87SignatureWithPublic
  final _i3.Dilithium87SignatureWithPublic value0;

  @override
  Map<String, Map<String, List<int>>> toJson() => {'Dilithium87': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i3.Dilithium87SignatureWithPublic.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    _i3.Dilithium87SignatureWithPublic.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Dilithium87 && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Dilithium65 extends DilithiumSignatureScheme {
  const Dilithium65(this.value0);

  factory Dilithium65._decode(_i1.Input input) {
    return Dilithium65(_i4.Dilithium65SignatureWithPublic.codec.decode(input));
  }

  /// Dilithium65SignatureWithPublic
  final _i4.Dilithium65SignatureWithPublic value0;

  @override
  Map<String, Map<String, List<int>>> toJson() => {'Dilithium65': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i4.Dilithium65SignatureWithPublic.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    _i4.Dilithium65SignatureWithPublic.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Dilithium65 && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}
