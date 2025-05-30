// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i3;

import 'b_tree_set_1.dart' as _i2;
import 'tuples.dart' as _i1;

typedef BTreeMap = List<_i1.Tuple2<int, _i2.BTreeSet>>;

class BTreeMapCodec with _i3.Codec<BTreeMap> {
  const BTreeMapCodec();

  @override
  BTreeMap decode(_i3.Input input) {
    return const _i3.SequenceCodec<_i1.Tuple2<int, _i2.BTreeSet>>(
        _i1.Tuple2Codec<int, _i2.BTreeSet>(
      _i3.U8Codec.codec,
      _i2.BTreeSetCodec(),
    )).decode(input);
  }

  @override
  void encodeTo(
    BTreeMap value,
    _i3.Output output,
  ) {
    const _i3.SequenceCodec<_i1.Tuple2<int, _i2.BTreeSet>>(
        _i1.Tuple2Codec<int, _i2.BTreeSet>(
      _i3.U8Codec.codec,
      _i2.BTreeSetCodec(),
    )).encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(BTreeMap value) {
    return const _i3.SequenceCodec<_i1.Tuple2<int, _i2.BTreeSet>>(
        _i1.Tuple2Codec<int, _i2.BTreeSet>(
      _i3.U8Codec.codec,
      _i2.BTreeSetCodec(),
    )).sizeHint(value);
  }
}
