// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:polkadart/scale_codec.dart' as _i2;

import 'tuples.dart' as _i1;

typedef BTreeMap = List<_i1.Tuple2<int, BigInt>>;

class BTreeMapCodec with _i2.Codec<BTreeMap> {
  const BTreeMapCodec();

  @override
  BTreeMap decode(_i2.Input input) {
    return const _i2.SequenceCodec<_i1.Tuple2<int, BigInt>>(
        _i1.Tuple2Codec<int, BigInt>(
      _i2.U32Codec.codec,
      _i2.U128Codec.codec,
    )).decode(input);
  }

  @override
  void encodeTo(
    BTreeMap value,
    _i2.Output output,
  ) {
    const _i2.SequenceCodec<_i1.Tuple2<int, BigInt>>(
        _i1.Tuple2Codec<int, BigInt>(
      _i2.U32Codec.codec,
      _i2.U128Codec.codec,
    )).encodeTo(
      value,
      output,
    );
  }

  @override
  int sizeHint(BTreeMap value) {
    return const _i2.SequenceCodec<_i1.Tuple2<int, BigInt>>(
        _i1.Tuple2Codec<int, BigInt>(
      _i2.U32Codec.codec,
      _i2.U128Codec.codec,
    )).sizeHint(value);
  }
}
