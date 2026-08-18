// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i3;

class Dilithium65SignatureWithPublic {
  const Dilithium65SignatureWithPublic({required this.bytes});

  factory Dilithium65SignatureWithPublic.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// [u8; Dilithium65SignatureWithPublic::TOTAL_LEN]
  final List<int> bytes;

  static const $Dilithium65SignatureWithPublicCodec codec = $Dilithium65SignatureWithPublicCodec();

  _i2.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, List<int>> toJson() => {'bytes': bytes.toList()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Dilithium65SignatureWithPublic && _i3.listsEqual(other.bytes, bytes);

  @override
  int get hashCode => bytes.hashCode;
}

class $Dilithium65SignatureWithPublicCodec with _i1.Codec<Dilithium65SignatureWithPublic> {
  const $Dilithium65SignatureWithPublicCodec();

  @override
  void encodeTo(Dilithium65SignatureWithPublic obj, _i1.Output output) {
    const _i1.U8ArrayCodec(5261).encodeTo(obj.bytes, output);
  }

  @override
  Dilithium65SignatureWithPublic decode(_i1.Input input) {
    return Dilithium65SignatureWithPublic(bytes: const _i1.U8ArrayCodec(5261).decode(input));
  }

  @override
  int sizeHint(Dilithium65SignatureWithPublic obj) {
    int size = 0;
    size = size + const _i1.U8ArrayCodec(5261).sizeHint(obj.bytes);
    return size;
  }
}
