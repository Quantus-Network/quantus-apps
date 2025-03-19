// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import 'wrapped_public_bytes.dart' as _i3;
import 'wrapped_signature_bytes.dart' as _i2;

class ResonanceSignatureWithPublic {
  const ResonanceSignatureWithPublic({
    required this.signature,
    required this.public,
    required this.bytes,
  });

  factory ResonanceSignatureWithPublic.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// ResonanceSignature
  final _i2.WrappedSignatureBytes signature;

  /// ResonancePublic
  final _i3.WrappedPublicBytes public;

  /// [u8; Self::TOTAL_LEN]
  final List<int> bytes;

  static const $ResonanceSignatureWithPublicCodec codec = $ResonanceSignatureWithPublicCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, List<int>> toJson() => {
        'signature': signature.toList(),
        'public': public.toList(),
        'bytes': bytes.toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ResonanceSignatureWithPublic &&
          _i5.listsEqual(
            other.signature,
            signature,
          ) &&
          _i5.listsEqual(
            other.public,
            public,
          ) &&
          _i5.listsEqual(
            other.bytes,
            bytes,
          );

  @override
  int get hashCode => Object.hash(
        signature,
        public,
        bytes,
      );
}

class $ResonanceSignatureWithPublicCodec with _i1.Codec<ResonanceSignatureWithPublic> {
  const $ResonanceSignatureWithPublicCodec();

  @override
  void encodeTo(
    ResonanceSignatureWithPublic obj,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(4627).encodeTo(
      obj.signature,
      output,
    );
    const _i1.U8ArrayCodec(2592).encodeTo(
      obj.public,
      output,
    );
    const _i1.U8ArrayCodec(7219).encodeTo(
      obj.bytes,
      output,
    );
  }

  @override
  ResonanceSignatureWithPublic decode(_i1.Input input) {
    return ResonanceSignatureWithPublic(
      signature: const _i1.U8ArrayCodec(4627).decode(input),
      public: const _i1.U8ArrayCodec(2592).decode(input),
      bytes: const _i1.U8ArrayCodec(7219).decode(input),
    );
  }

  @override
  int sizeHint(ResonanceSignatureWithPublic obj) {
    int size = 0;
    size = size + const _i2.WrappedSignatureBytesCodec().sizeHint(obj.signature);
    size = size + const _i3.WrappedPublicBytesCodec().sizeHint(obj.public);
    size = size + const _i1.U8ArrayCodec(7219).sizeHint(obj.bytes);
    return size;
  }
}
