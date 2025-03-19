// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i3;

class ResonanceSignatureWithPublic {
  const ResonanceSignatureWithPublic({required this.bytes});

  factory ResonanceSignatureWithPublic.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// [u8; Self::TOTAL_LEN]
  final List<int> bytes;

  static const $ResonanceSignatureWithPublicCodec codec =
      $ResonanceSignatureWithPublicCodec();

  _i2.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, List<int>> toJson() => {'bytes': bytes.toList()};

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ResonanceSignatureWithPublic &&
          _i3.listsEqual(
            other.bytes,
            bytes,
          );

  @override
  int get hashCode => bytes.hashCode;
}

class $ResonanceSignatureWithPublicCodec
    with _i1.Codec<ResonanceSignatureWithPublic> {
  const $ResonanceSignatureWithPublicCodec();

  @override
  void encodeTo(
    ResonanceSignatureWithPublic obj,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(7219).encodeTo(
      obj.bytes,
      output,
    );
  }

  @override
  ResonanceSignatureWithPublic decode(_i1.Input input) {
    return ResonanceSignatureWithPublic(
        bytes: const _i1.U8ArrayCodec(7219).decode(input));
  }

  @override
  int sizeHint(ResonanceSignatureWithPublic obj) {
    int size = 0;
    size = size + const _i1.U8ArrayCodec(7219).sizeHint(obj.bytes);
    return size;
  }
}
