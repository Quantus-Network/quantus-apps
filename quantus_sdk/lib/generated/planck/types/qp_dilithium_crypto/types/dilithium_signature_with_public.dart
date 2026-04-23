// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i3;

class DilithiumSignatureWithPublic {
  const DilithiumSignatureWithPublic({required this.bytes});

  factory DilithiumSignatureWithPublic.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// [u8; DilithiumSignatureWithPublic::TOTAL_LEN]
  final List<int> bytes;

  static const $DilithiumSignatureWithPublicCodec codec = $DilithiumSignatureWithPublicCodec();

  _i2.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, List<int>> toJson() => {'bytes': bytes.toList()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DilithiumSignatureWithPublic && _i3.listsEqual(other.bytes, bytes);

  @override
  int get hashCode => bytes.hashCode;
}

class $DilithiumSignatureWithPublicCodec with _i1.Codec<DilithiumSignatureWithPublic> {
  const $DilithiumSignatureWithPublicCodec();

  @override
  void encodeTo(DilithiumSignatureWithPublic obj, _i1.Output output) {
    const _i1.U8ArrayCodec(7219).encodeTo(obj.bytes, output);
  }

  @override
  DilithiumSignatureWithPublic decode(_i1.Input input) {
    return DilithiumSignatureWithPublic(bytes: const _i1.U8ArrayCodec(7219).decode(input));
  }

  @override
  int sizeHint(DilithiumSignatureWithPublic obj) {
    int size = 0;
    size = size + const _i1.U8ArrayCodec(7219).sizeHint(obj.bytes);
    return size;
  }
}
