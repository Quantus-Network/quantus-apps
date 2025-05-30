// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../frame_support/traits/preimages/bounded.dart' as _i3;
import '../sp_core/crypto/account_id32.dart' as _i2;

class PendingTransfer {
  const PendingTransfer({
    required this.who,
    required this.call,
    required this.amount,
    required this.count,
  });

  factory PendingTransfer.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// AccountId
  final _i2.AccountId32 who;

  /// Call
  final _i3.Bounded call;

  /// Balance
  final BigInt amount;

  /// u32
  final int count;

  static const $PendingTransferCodec codec = $PendingTransferCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'who': who.toList(),
        'call': call.toJson(),
        'amount': amount,
        'count': count,
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PendingTransfer &&
          _i5.listsEqual(
            other.who,
            who,
          ) &&
          other.call == call &&
          other.amount == amount &&
          other.count == count;

  @override
  int get hashCode => Object.hash(
        who,
        call,
        amount,
        count,
      );
}

class $PendingTransferCodec with _i1.Codec<PendingTransfer> {
  const $PendingTransferCodec();

  @override
  void encodeTo(
    PendingTransfer obj,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.who,
      output,
    );
    _i3.Bounded.codec.encodeTo(
      obj.call,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      obj.amount,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      obj.count,
      output,
    );
  }

  @override
  PendingTransfer decode(_i1.Input input) {
    return PendingTransfer(
      who: const _i1.U8ArrayCodec(32).decode(input),
      call: _i3.Bounded.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      count: _i1.U32Codec.codec.decode(input),
    );
  }

  @override
  int sizeHint(PendingTransfer obj) {
    int size = 0;
    size = size + const _i2.AccountId32Codec().sizeHint(obj.who);
    size = size + _i3.Bounded.codec.sizeHint(obj.call);
    size = size + _i1.U128Codec.codec.sizeHint(obj.amount);
    size = size + _i1.U32Codec.codec.sizeHint(obj.count);
    return size;
  }
}
