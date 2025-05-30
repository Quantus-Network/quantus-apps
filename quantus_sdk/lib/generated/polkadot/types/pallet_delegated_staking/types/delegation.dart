// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i2;

class Delegation {
  const Delegation({
    required this.agent,
    required this.amount,
  });

  factory Delegation.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// T::AccountId
  final _i2.AccountId32 agent;

  /// BalanceOf<T>
  final BigInt amount;

  static const $DelegationCodec codec = $DelegationCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'agent': agent.toList(),
        'amount': amount,
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Delegation &&
          _i4.listsEqual(
            other.agent,
            agent,
          ) &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        agent,
        amount,
      );
}

class $DelegationCodec with _i1.Codec<Delegation> {
  const $DelegationCodec();

  @override
  void encodeTo(
    Delegation obj,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.agent,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      obj.amount,
      output,
    );
  }

  @override
  Delegation decode(_i1.Input input) {
    return Delegation(
      agent: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  @override
  int sizeHint(Delegation obj) {
    int size = 0;
    size = size + const _i2.AccountId32Codec().sizeHint(obj.agent);
    size = size + _i1.U128Codec.codec.sizeHint(obj.amount);
    return size;
  }
}
