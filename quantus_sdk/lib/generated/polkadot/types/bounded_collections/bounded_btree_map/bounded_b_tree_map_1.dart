// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i2;

import '../../b_tree_map_2.dart' as _i1;
import '../../tuples.dart' as _i3;

typedef BoundedBTreeMap = _i1.BTreeMap;

class BoundedBTreeMapCodec with _i2.Codec<BoundedBTreeMap> {
  const BoundedBTreeMapCodec();

  @override
  BoundedBTreeMap decode(_i2.Input input) {
    return const _i2.SequenceCodec<_i3.Tuple2<int, BigInt>>(
        _i3.Tuple2Codec<int, BigInt>(
      _i2.U32Codec.codec,
      _i2.U128Codec.codec,
    )).decode(input);
  }

  @override
  void encodeTo(
    BoundedBTreeMap value,
    _i2.Output output,
  ) {
    const _i2.SequenceCodec<_i3.Tuple2<int, BigInt>>(
        _i3.Tuple2Codec<int, BigInt>(
      _i2.U32Codec.codec,
      _i2.U128Codec.codec,
    )).encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(BoundedBTreeMap value) {
    return const _i1.BTreeMapCodec().sizeHint(value);
  }
}
