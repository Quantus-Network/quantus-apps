// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i3;

class Dilithium87SignatureWithPublic {
  const Dilithium87SignatureWithPublic({required this.bytes});

  factory Dilithium87SignatureWithPublic.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// [u8; Dilithium87SignatureWithPublic::TOTAL_LEN]
  final List<int> bytes;

  static const $Dilithium87SignatureWithPublicCodec codec = $Dilithium87SignatureWithPublicCodec();

  _i2.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, List<int>> toJson() => {'bytes': bytes.toList()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Dilithium87SignatureWithPublic && _i3.listsEqual(other.bytes, bytes);

  @override
  int get hashCode => bytes.hashCode;
}

class $Dilithium87SignatureWithPublicCodec with _i1.Codec<Dilithium87SignatureWithPublic> {
  const $Dilithium87SignatureWithPublicCodec();

  @override
  void encodeTo(Dilithium87SignatureWithPublic obj, _i1.Output output) {
    const _i1.U8ArrayCodec(7219).encodeTo(obj.bytes, output);
  }

  @override
  Dilithium87SignatureWithPublic decode(_i1.Input input) {
    return Dilithium87SignatureWithPublic(bytes: const _i1.U8ArrayCodec(7219).decode(input));
  }

  @override
  int sizeHint(Dilithium87SignatureWithPublic obj) {
    int size = 0;
    size = size + const _i1.U8ArrayCodec(7219).sizeHint(obj.bytes);
    return size;
  }
}
