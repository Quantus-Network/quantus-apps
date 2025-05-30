// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i1;

typedef WrappedSignatureBytes = List<int>;

class WrappedSignatureBytesCodec with _i1.Codec<WrappedSignatureBytes> {
  const WrappedSignatureBytesCodec();

  @override
  WrappedSignatureBytes decode(_i1.Input input) {
    return const _i1.U8ArrayCodec(4627).decode(input);
  }

  @override
  void encodeTo(
    WrappedSignatureBytes value,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(4627).encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(WrappedSignatureBytes value) {
    return const _i1.U8ArrayCodec(4627).sizeHint(value);
  }
}
