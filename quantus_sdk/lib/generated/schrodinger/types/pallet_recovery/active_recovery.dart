// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../sp_core/crypto/account_id32.dart' as _i2;

class ActiveRecovery {
  const ActiveRecovery({
    required this.created,
    required this.deposit,
    required this.friends,
  });

  factory ActiveRecovery.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// BlockNumber
  final int created;

  /// Balance
  final BigInt deposit;

  /// Friends
  final List<_i2.AccountId32> friends;

  static const $ActiveRecoveryCodec codec = $ActiveRecoveryCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'created': created,
        'deposit': deposit,
        'friends': friends.map((value) => value.toList()).toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ActiveRecovery &&
          other.created == created &&
          other.deposit == deposit &&
          _i4.listsEqual(
            other.friends,
            friends,
          );

  @override
  int get hashCode => Object.hash(
        created,
        deposit,
        friends,
      );
}

class $ActiveRecoveryCodec with _i1.Codec<ActiveRecovery> {
  const $ActiveRecoveryCodec();

  @override
  void encodeTo(
    ActiveRecovery obj,
    _i1.Output output,
  ) {
    _i1.U32Codec.codec.encodeTo(
      obj.created,
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
  }

  @override
  ActiveRecovery decode(_i1.Input input) {
    return ActiveRecovery(
      created: _i1.U32Codec.codec.decode(input),
      deposit: _i1.U128Codec.codec.decode(input),
      friends: const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec())
          .decode(input),
    );
  }

  @override
  int sizeHint(ActiveRecovery obj) {
    int size = 0;
    size = size + _i1.U32Codec.codec.sizeHint(obj.created);
    size = size + _i1.U128Codec.codec.sizeHint(obj.deposit);
    size = size +
        const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec())
            .sizeHint(obj.friends);
    return size;
  }
}
