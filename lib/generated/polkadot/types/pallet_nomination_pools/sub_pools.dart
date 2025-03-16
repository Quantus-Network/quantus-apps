// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../bounded_collections/bounded_btree_map/bounded_b_tree_map_2.dart'
    as _i3;
import '../tuples.dart' as _i5;
import 'unbond_pool.dart' as _i2;

class SubPools {
  const SubPools({
    required this.noEra,
    required this.withEra,
  });

  factory SubPools.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// UnbondPool<T>
  final _i2.UnbondPool noEra;

  /// BoundedBTreeMap<EraIndex, UnbondPool<T>, TotalUnbondingPools<T>>
  final _i3.BoundedBTreeMap withEra;

  static const $SubPoolsCodec codec = $SubPoolsCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'noEra': noEra.toJson(),
        'withEra': withEra
            .map((value) => [
                  value.value0,
                  value.value1.toJson(),
                ])
            .toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is SubPools && other.noEra == noEra && other.withEra == withEra;

  @override
  int get hashCode => Object.hash(
        noEra,
        withEra,
      );
}

class $SubPoolsCodec with _i1.Codec<SubPools> {
  const $SubPoolsCodec();

  @override
  void encodeTo(
    SubPools obj,
    _i1.Output output,
  ) {
    _i2.UnbondPool.codec.encodeTo(
      obj.noEra,
      output,
    );
    const _i1.SequenceCodec<_i5.Tuple2<int, _i2.UnbondPool>>(
        _i5.Tuple2Codec<int, _i2.UnbondPool>(
      _i1.U32Codec.codec,
      _i2.UnbondPool.codec,
    )).encodeTo(
      obj.withEra,
      output,
    );
  }

  @override
  SubPools decode(_i1.Input input) {
    return SubPools(
      noEra: _i2.UnbondPool.codec.decode(input),
      withEra: const _i1.SequenceCodec<_i5.Tuple2<int, _i2.UnbondPool>>(
          _i5.Tuple2Codec<int, _i2.UnbondPool>(
        _i1.U32Codec.codec,
        _i2.UnbondPool.codec,
      )).decode(input),
    );
  }

  @override
  int sizeHint(SubPools obj) {
    int size = 0;
    size = size + _i2.UnbondPool.codec.sizeHint(obj.noEra);
    size = size + const _i3.BoundedBTreeMapCodec().sizeHint(obj.withEra);
    return size;
  }
}
