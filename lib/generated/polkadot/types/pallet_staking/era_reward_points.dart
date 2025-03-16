// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../b_tree_map_1.dart' as _i2;
import '../sp_core/crypto/account_id32.dart' as _i6;
import '../tuples.dart' as _i5;

class EraRewardPoints {
  const EraRewardPoints({
    required this.total,
    required this.individual,
  });

  factory EraRewardPoints.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// RewardPoint
  final int total;

  /// BTreeMap<AccountId, RewardPoint>
  final _i2.BTreeMap individual;

  static const $EraRewardPointsCodec codec = $EraRewardPointsCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'total': total,
        'individual': individual
            .map((value) => [
                  value.value0.toList(),
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
      other is EraRewardPoints &&
          other.total == total &&
          _i4.listsEqual(
            other.individual,
            individual,
          );

  @override
  int get hashCode => Object.hash(
        total,
        individual,
      );
}

class $EraRewardPointsCodec with _i1.Codec<EraRewardPoints> {
  const $EraRewardPointsCodec();

  @override
  void encodeTo(
    EraRewardPoints obj,
    _i1.Output output,
  ) {
    _i1.U32Codec.codec.encodeTo(
      obj.total,
      output,
    );
    const _i1.SequenceCodec<_i5.Tuple2<_i6.AccountId32, int>>(
        _i5.Tuple2Codec<_i6.AccountId32, int>(
      _i6.AccountId32Codec(),
      _i1.U32Codec.codec,
    )).encodeTo(
      obj.individual,
      output,
    );
  }

  @override
  EraRewardPoints decode(_i1.Input input) {
    return EraRewardPoints(
      total: _i1.U32Codec.codec.decode(input),
      individual: const _i1.SequenceCodec<_i5.Tuple2<_i6.AccountId32, int>>(
          _i5.Tuple2Codec<_i6.AccountId32, int>(
        _i6.AccountId32Codec(),
        _i1.U32Codec.codec,
      )).decode(input),
    );
  }

  @override
  int sizeHint(EraRewardPoints obj) {
    int size = 0;
    size = size + _i1.U32Codec.codec.sizeHint(obj.total);
    size = size + const _i2.BTreeMapCodec().sizeHint(obj.individual);
    return size;
  }
}
