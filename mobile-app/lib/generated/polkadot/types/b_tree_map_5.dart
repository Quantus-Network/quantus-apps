// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i4;

import 'polkadot_primitives/v8/validator_app/public.dart' as _i3;
import 'polkadot_primitives/v8/validator_index.dart' as _i2;
import 'tuples.dart' as _i1;

typedef BTreeMap = List<_i1.Tuple2<_i2.ValidatorIndex, _i3.Public>>;

class BTreeMapCodec with _i4.Codec<BTreeMap> {
  const BTreeMapCodec();

  @override
  BTreeMap decode(_i4.Input input) {
    return const _i4.SequenceCodec<_i1.Tuple2<_i2.ValidatorIndex, _i3.Public>>(
        _i1.Tuple2Codec<_i2.ValidatorIndex, _i3.Public>(
      _i2.ValidatorIndexCodec(),
      _i3.PublicCodec(),
    )).decode(input);
  }

  @override
  void encodeTo(
    BTreeMap value,
    _i4.Output output,
  ) {
    const _i4.SequenceCodec<_i1.Tuple2<_i2.ValidatorIndex, _i3.Public>>(
        _i1.Tuple2Codec<_i2.ValidatorIndex, _i3.Public>(
      _i2.ValidatorIndexCodec(),
      _i3.PublicCodec(),
    )).encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(BTreeMap value) {
    return const _i4.SequenceCodec<_i1.Tuple2<_i2.ValidatorIndex, _i3.Public>>(
        _i1.Tuple2Codec<_i2.ValidatorIndex, _i3.Public>(
      _i2.ValidatorIndexCodec(),
      _i3.PublicCodec(),
    )).sizeHint(value);
  }
}
