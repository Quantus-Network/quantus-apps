// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../sp_core/crypto/account_id32.dart' as _i2;

class RecoveryConfig {
  const RecoveryConfig({
    required this.delayPeriod,
    required this.deposit,
    required this.friends,
    required this.threshold,
  });

  factory RecoveryConfig.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// BlockNumber
  final int delayPeriod;

  /// Balance
  final BigInt deposit;

  /// Friends
  final List<_i2.AccountId32> friends;

  /// u16
  final int threshold;

  static const $RecoveryConfigCodec codec = $RecoveryConfigCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'delayPeriod': delayPeriod,
        'deposit': deposit,
        'friends': friends.map((value) => value.toList()).toList(),
        'threshold': threshold,
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RecoveryConfig &&
          other.delayPeriod == delayPeriod &&
          other.deposit == deposit &&
          _i4.listsEqual(
            other.friends,
            friends,
          ) &&
          other.threshold == threshold;

  @override
  int get hashCode => Object.hash(
        delayPeriod,
        deposit,
        friends,
        threshold,
      );
}

class $RecoveryConfigCodec with _i1.Codec<RecoveryConfig> {
  const $RecoveryConfigCodec();

  @override
  void encodeTo(
    RecoveryConfig obj,
    _i1.Output output,
  ) {
    _i1.U32Codec.codec.encodeTo(
      obj.delayPeriod,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      obj.deposit,
      output,
    );
    const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec()).encodeTo(
      obj.friends,
      output,
    );
    _i1.U16Codec.codec.encodeTo(
      obj.threshold,
      output,
    );
  }

  @override
  RecoveryConfig decode(_i1.Input input) {
    return RecoveryConfig(
      delayPeriod: _i1.U32Codec.codec.decode(input),
      deposit: _i1.U128Codec.codec.decode(input),
      friends: const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec())
          .decode(input),
      threshold: _i1.U16Codec.codec.decode(input),
    );
  }

  @override
  int sizeHint(RecoveryConfig obj) {
    int size = 0;
    size = size + _i1.U32Codec.codec.sizeHint(obj.delayPeriod);
    size = size + _i1.U128Codec.codec.sizeHint(obj.deposit);
    size = size +
        const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec())
            .sizeHint(obj.friends);
    size = size + _i1.U16Codec.codec.sizeHint(obj.threshold);
    return size;
  }
}
