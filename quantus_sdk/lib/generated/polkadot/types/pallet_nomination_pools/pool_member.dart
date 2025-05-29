// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../bounded_collections/bounded_btree_map/bounded_b_tree_map_1.dart'
    as _i3;
import '../sp_arithmetic/fixed_point/fixed_u128.dart' as _i2;
import '../tuples.dart' as _i5;

class PoolMember {
  const PoolMember({
    required this.poolId,
    required this.points,
    required this.lastRecordedRewardCounter,
    required this.unbondingEras,
  });

  factory PoolMember.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// PoolId
  final int poolId;

  /// BalanceOf<T>
  final BigInt points;

  /// T::RewardCounter
  final _i2.FixedU128 lastRecordedRewardCounter;

  /// BoundedBTreeMap<EraIndex, BalanceOf<T>, T::MaxUnbonding>
  final _i3.BoundedBTreeMap unbondingEras;

  static const $PoolMemberCodec codec = $PoolMemberCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'poolId': poolId,
        'points': points,
        'lastRecordedRewardCounter': lastRecordedRewardCounter,
        'unbondingEras': unbondingEras
            .map((value) => [
                  value.value0,
                  value.value1,
                ])
            .toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PoolMember &&
          other.poolId == poolId &&
          other.points == points &&
          other.lastRecordedRewardCounter == lastRecordedRewardCounter &&
          other.unbondingEras == unbondingEras;

  @override
  int get hashCode => Object.hash(
        poolId,
        points,
        lastRecordedRewardCounter,
        unbondingEras,
      );
}

class $PoolMemberCodec with _i1.Codec<PoolMember> {
  const $PoolMemberCodec();

  @override
  void encodeTo(
    PoolMember obj,
    _i1.Output output,
  ) {
    _i1.U32Codec.codec.encodeTo(
      obj.poolId,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      obj.points,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      obj.lastRecordedRewardCounter,
      output,
    );
    const _i1.SequenceCodec<_i5.Tuple2<int, BigInt>>(
        _i5.Tuple2Codec<int, BigInt>(
      _i1.U32Codec.codec,
      _i1.U128Codec.codec,
    )).encodeTo(
      obj.unbondingEras,
      output,
    );
  }

  @override
  PoolMember decode(_i1.Input input) {
    return PoolMember(
      poolId: _i1.U32Codec.codec.decode(input),
      points: _i1.U128Codec.codec.decode(input),
      lastRecordedRewardCounter: _i1.U128Codec.codec.decode(input),
      unbondingEras: const _i1.SequenceCodec<_i5.Tuple2<int, BigInt>>(
          _i5.Tuple2Codec<int, BigInt>(
        _i1.U32Codec.codec,
        _i1.U128Codec.codec,
      )).decode(input),
    );
  }

  @override
  int sizeHint(PoolMember obj) {
    int size = 0;
    size = size + _i1.U32Codec.codec.sizeHint(obj.poolId);
    size = size + _i1.U128Codec.codec.sizeHint(obj.points);
    size = size +
        const _i2.FixedU128Codec().sizeHint(obj.lastRecordedRewardCounter);
    size = size + const _i3.BoundedBTreeMapCodec().sizeHint(obj.unbondingEras);
    return size;
  }
}
