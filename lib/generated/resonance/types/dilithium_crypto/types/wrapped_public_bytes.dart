// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i1;

typedef WrappedPublicBytes = List<int>;

class WrappedPublicBytesCodec with _i1.Codec<WrappedPublicBytes> {
  const WrappedPublicBytesCodec();

  @override
  WrappedPublicBytes decode(_i1.Input input) {
    return const _i1.U8ArrayCodec(2592).decode(input);
  }

  @override
  void encodeTo(
    WrappedPublicBytes value,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(2592).encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(WrappedPublicBytes value) {
    return const _i1.U8ArrayCodec(2592).sizeHint(value);
  }
}
