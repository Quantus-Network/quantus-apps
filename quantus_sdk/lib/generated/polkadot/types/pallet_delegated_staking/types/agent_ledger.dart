// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i2;

class AgentLedger {
  const AgentLedger({
    required this.payee,
    required this.totalDelegated,
    required this.unclaimedWithdrawals,
    required this.pendingSlash,
  });

  factory AgentLedger.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// T::AccountId
  final _i2.AccountId32 payee;

  /// BalanceOf<T>
  final BigInt totalDelegated;

  /// BalanceOf<T>
  final BigInt unclaimedWithdrawals;

  /// BalanceOf<T>
  final BigInt pendingSlash;

  static const $AgentLedgerCodec codec = $AgentLedgerCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'payee': payee.toList(),
        'totalDelegated': totalDelegated,
        'unclaimedWithdrawals': unclaimedWithdrawals,
        'pendingSlash': pendingSlash,
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is AgentLedger &&
          _i4.listsEqual(
            other.payee,
            payee,
          ) &&
          other.totalDelegated == totalDelegated &&
          other.unclaimedWithdrawals == unclaimedWithdrawals &&
          other.pendingSlash == pendingSlash;

  @override
  int get hashCode => Object.hash(
        payee,
        totalDelegated,
        unclaimedWithdrawals,
        pendingSlash,
      );
}

class $AgentLedgerCodec with _i1.Codec<AgentLedger> {
  const $AgentLedgerCodec();

  @override
  void encodeTo(
    AgentLedger obj,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.payee,
      output,
    );
    _i1.CompactBigIntCodec.codec.encodeTo(
      obj.totalDelegated,
      output,
    );
    _i1.CompactBigIntCodec.codec.encodeTo(
      obj.unclaimedWithdrawals,
      output,
    );
    _i1.CompactBigIntCodec.codec.encodeTo(
      obj.pendingSlash,
      output,
    );
  }

  @override
  AgentLedger decode(_i1.Input input) {
    return AgentLedger(
      payee: const _i1.U8ArrayCodec(32).decode(input),
      totalDelegated: _i1.CompactBigIntCodec.codec.decode(input),
      unclaimedWithdrawals: _i1.CompactBigIntCodec.codec.decode(input),
      pendingSlash: _i1.CompactBigIntCodec.codec.decode(input),
    );
  }

  @override
  int sizeHint(AgentLedger obj) {
    int size = 0;
    size = size + const _i2.AccountId32Codec().sizeHint(obj.payee);
    size = size + _i1.CompactBigIntCodec.codec.sizeHint(obj.totalDelegated);
    size =
        size + _i1.CompactBigIntCodec.codec.sizeHint(obj.unclaimedWithdrawals);
    size = size + _i1.CompactBigIntCodec.codec.sizeHint(obj.pendingSlash);
    return size;
  }
}
