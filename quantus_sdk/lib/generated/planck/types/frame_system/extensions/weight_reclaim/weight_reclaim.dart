// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i1;

typedef WeightReclaim = dynamic;

class WeightReclaimCodec with _i1.Codec<WeightReclaim> {
  const WeightReclaimCodec();

  @override
  WeightReclaim decode(_i1.Input input) {
    return _i1.NullCodec.codec.decode(input);
  }

  @override
  void encodeTo(WeightReclaim value, _i1.Output output) {
    _i1.NullCodec.codec.encodeTo(value, output);
  }

  @override
  int sizeHint(WeightReclaim value) {
    return _i1.NullCodec.codec.sizeHint(value);
  }
}
