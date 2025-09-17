// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

import 'dilithium_signature_with_public.dart' as _i3;

abstract class DilithiumSignatureScheme {
  const DilithiumSignatureScheme();

  factory DilithiumSignatureScheme.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $DilithiumSignatureSchemeCodec codec =
      $DilithiumSignatureSchemeCodec();

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

  Dilithium dilithium(_i3.DilithiumSignatureWithPublic value0) {
    return Dilithium(value0);
  }
}

class $DilithiumSignatureSchemeCodec with _i1.Codec<DilithiumSignatureScheme> {
  const $DilithiumSignatureSchemeCodec();

  @override
  DilithiumSignatureScheme decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Dilithium._decode(input);
      default:
        throw Exception(
            'DilithiumSignatureScheme: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    DilithiumSignatureScheme value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case Dilithium:
        (value as Dilithium).encodeTo(output);
        break;
      default:
        throw Exception(
            'DilithiumSignatureScheme: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(DilithiumSignatureScheme value) {
    switch (value.runtimeType) {
      case Dilithium:
        return (value as Dilithium)._sizeHint();
      default:
        throw Exception(
            'DilithiumSignatureScheme: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class Dilithium extends DilithiumSignatureScheme {
  const Dilithium(this.value0);

  factory Dilithium._decode(_i1.Input input) {
    return Dilithium(_i3.DilithiumSignatureWithPublic.codec.decode(input));
  }

  /// DilithiumSignatureWithPublic
  final _i3.DilithiumSignatureWithPublic value0;

  @override
  Map<String, Map<String, List<int>>> toJson() =>
      {'Dilithium': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i3.DilithiumSignatureWithPublic.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i3.DilithiumSignatureWithPublic.codec.encodeTo(
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
      other is Dilithium && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}
