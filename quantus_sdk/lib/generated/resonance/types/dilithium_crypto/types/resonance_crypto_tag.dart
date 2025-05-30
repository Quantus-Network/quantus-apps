// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i1;

typedef ResonanceCryptoTag = dynamic;

class ResonanceCryptoTagCodec with _i1.Codec<ResonanceCryptoTag> {
  const ResonanceCryptoTagCodec();

  @override
  ResonanceCryptoTag decode(_i1.Input input) {
    return _i1.NullCodec.codec.decode(input);
  }

  @override
  void encodeTo(
    ResonanceCryptoTag value,
    _i1.Output output,
  ) {
    _i1.NullCodec.codec.encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(ResonanceCryptoTag value) {
    return _i1.NullCodec.codec.sizeHint(value);
  }
}
