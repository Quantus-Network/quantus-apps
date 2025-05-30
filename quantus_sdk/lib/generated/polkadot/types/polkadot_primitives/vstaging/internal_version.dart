// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i1;

typedef InternalVersion = int;

class InternalVersionCodec with _i1.Codec<InternalVersion> {
  const InternalVersionCodec();

  @override
  InternalVersion decode(_i1.Input input) {
    return _i1.U8Codec.codec.decode(input);
  }

  @override
  void encodeTo(
    InternalVersion value,
    _i1.Output output,
  ) {
    _i1.U8Codec.codec.encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(InternalVersion value) {
    return _i1.U8Codec.codec.sizeHint(value);
  }
}
