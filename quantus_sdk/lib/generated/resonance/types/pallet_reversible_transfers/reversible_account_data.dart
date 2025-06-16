// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i5;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../qp_scheduler/block_number_or_timestamp.dart' as _i3;
import '../sp_core/crypto/account_id32.dart' as _i2;
import 'delay_policy.dart' as _i4;

class ReversibleAccountData {
  const ReversibleAccountData({
    this.explicitReverser,
    required this.delay,
    required this.policy,
  });

  factory ReversibleAccountData.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// Option<AccountId>
  final _i2.AccountId32? explicitReverser;

  /// Delay
  final _i3.BlockNumberOrTimestamp delay;

  /// DelayPolicy
  final _i4.DelayPolicy policy;

  static const $ReversibleAccountDataCodec codec =
      $ReversibleAccountDataCodec();

  _i5.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'explicitReverser': explicitReverser?.toList(),
        'delay': delay.toJson(),
        'policy': policy.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ReversibleAccountData &&
          other.explicitReverser == explicitReverser &&
          other.delay == delay &&
          other.policy == policy;

  @override
  int get hashCode => Object.hash(
        explicitReverser,
        delay,
        policy,
      );
}

class $ReversibleAccountDataCodec with _i1.Codec<ReversibleAccountData> {
  const $ReversibleAccountDataCodec();

  @override
  void encodeTo(
    ReversibleAccountData obj,
    _i1.Output output,
  ) {
    const _i1.OptionCodec<_i2.AccountId32>(_i2.AccountId32Codec()).encodeTo(
      obj.explicitReverser,
      output,
    );
    _i3.BlockNumberOrTimestamp.codec.encodeTo(
      obj.delay,
      output,
    );
    _i4.DelayPolicy.codec.encodeTo(
      obj.policy,
      output,
    );
  }

  @override
  ReversibleAccountData decode(_i1.Input input) {
    return ReversibleAccountData(
      explicitReverser:
          const _i1.OptionCodec<_i2.AccountId32>(_i2.AccountId32Codec())
              .decode(input),
      delay: _i3.BlockNumberOrTimestamp.codec.decode(input),
      policy: _i4.DelayPolicy.codec.decode(input),
    );
  }

  @override
  int sizeHint(ReversibleAccountData obj) {
    int size = 0;
    size = size +
        const _i1.OptionCodec<_i2.AccountId32>(_i2.AccountId32Codec())
            .sizeHint(obj.explicitReverser);
    size = size + _i3.BlockNumberOrTimestamp.codec.sizeHint(obj.delay);
    size = size + _i4.DelayPolicy.codec.sizeHint(obj.policy);
    return size;
  }
}
