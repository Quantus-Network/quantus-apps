// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import 'resonance_signature_with_public.dart' as _i3;

abstract class ResonanceSignatureScheme {
  const ResonanceSignatureScheme();

  factory ResonanceSignatureScheme.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $ResonanceSignatureSchemeCodec codec =
      $ResonanceSignatureSchemeCodec();

  static const $ResonanceSignatureScheme values = $ResonanceSignatureScheme();

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

class $ResonanceSignatureScheme {
  const $ResonanceSignatureScheme();

  Ed25519 ed25519(List<int> value0) {
    return Ed25519(value0);
  }

  Sr25519 sr25519(List<int> value0) {
    return Sr25519(value0);
  }

  Ecdsa ecdsa(List<int> value0) {
    return Ecdsa(value0);
  }

  Resonance resonance(_i3.ResonanceSignatureWithPublic value0) {
    return Resonance(value0);
  }
}

class $ResonanceSignatureSchemeCodec with _i1.Codec<ResonanceSignatureScheme> {
  const $ResonanceSignatureSchemeCodec();

  @override
  ResonanceSignatureScheme decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Ed25519._decode(input);
      case 1:
        return Sr25519._decode(input);
      case 2:
        return Ecdsa._decode(input);
      case 3:
        return Resonance._decode(input);
      default:
        throw Exception(
            'ResonanceSignatureScheme: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    ResonanceSignatureScheme value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case Ed25519:
        (value as Ed25519).encodeTo(output);
        break;
      case Sr25519:
        (value as Sr25519).encodeTo(output);
        break;
      case Ecdsa:
        (value as Ecdsa).encodeTo(output);
        break;
      case Resonance:
        (value as Resonance).encodeTo(output);
        break;
      default:
        throw Exception(
            'ResonanceSignatureScheme: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(ResonanceSignatureScheme value) {
    switch (value.runtimeType) {
      case Ed25519:
        return (value as Ed25519)._sizeHint();
      case Sr25519:
        return (value as Sr25519)._sizeHint();
      case Ecdsa:
        return (value as Ecdsa)._sizeHint();
      case Resonance:
        return (value as Resonance)._sizeHint();
      default:
        throw Exception(
            'ResonanceSignatureScheme: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class Ed25519 extends ResonanceSignatureScheme {
  const Ed25519(this.value0);

  factory Ed25519._decode(_i1.Input input) {
    return Ed25519(const _i1.U8ArrayCodec(64).decode(input));
  }

  /// ed25519::Signature
  final List<int> value0;

  @override
  Map<String, List<int>> toJson() => {'Ed25519': value0.toList()};

  int _sizeHint() {
    int size = 1;
    size = size + const _i1.U8ArrayCodec(64).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(64).encodeTo(
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
      other is Ed25519 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class Sr25519 extends ResonanceSignatureScheme {
  const Sr25519(this.value0);

  factory Sr25519._decode(_i1.Input input) {
    return Sr25519(const _i1.U8ArrayCodec(64).decode(input));
  }

  /// sr25519::Signature
  final List<int> value0;

  @override
  Map<String, List<int>> toJson() => {'Sr25519': value0.toList()};

  int _sizeHint() {
    int size = 1;
    size = size + const _i1.U8ArrayCodec(64).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(64).encodeTo(
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
      other is Sr25519 &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class Ecdsa extends ResonanceSignatureScheme {
  const Ecdsa(this.value0);

  factory Ecdsa._decode(_i1.Input input) {
    return Ecdsa(const _i1.U8ArrayCodec(65).decode(input));
  }

  /// ecdsa::Signature
  final List<int> value0;

  @override
  Map<String, List<int>> toJson() => {'Ecdsa': value0.toList()};

  int _sizeHint() {
    int size = 1;
    size = size + const _i1.U8ArrayCodec(65).sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.U8ArrayCodec(65).encodeTo(
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
      other is Ecdsa &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}

class Resonance extends ResonanceSignatureScheme {
  const Resonance(this.value0);

  factory Resonance._decode(_i1.Input input) {
    return Resonance(_i3.ResonanceSignatureWithPublic.codec.decode(input));
  }

  /// ResonanceSignatureWithPublic
  final _i3.ResonanceSignatureWithPublic value0;

  @override
  Map<String, Map<String, List<int>>> toJson() =>
      {'Resonance': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i3.ResonanceSignatureWithPublic.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    _i3.ResonanceSignatureWithPublic.codec.encodeTo(
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
      other is Resonance && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}
