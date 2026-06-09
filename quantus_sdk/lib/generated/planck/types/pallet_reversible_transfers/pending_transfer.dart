// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../sp_core/crypto/account_id32.dart' as _i2;

class PendingTransfer {
  const PendingTransfer({
    required this.from,
    required this.to,
    required this.guardian,
    this.assetId,
    required this.amount,
  });

  factory PendingTransfer.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// AccountId
  final _i2.AccountId32 from;

  /// AccountId
  final _i2.AccountId32 to;

  /// AccountId
  final _i2.AccountId32 guardian;

  /// Option<AssetId>
  final int? assetId;

  /// Balance
  final BigInt amount;

  static const $PendingTransferCodec codec = $PendingTransferCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
    'from': from.toList(),
    'to': to.toList(),
    'guardian': guardian.toList(),
    'assetId': assetId,
    'amount': amount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingTransfer &&
          _i4.listsEqual(other.from, from) &&
          _i4.listsEqual(other.to, to) &&
          _i4.listsEqual(other.guardian, guardian) &&
          other.assetId == assetId &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(from, to, guardian, assetId, amount);
}

class $PendingTransferCodec with _i1.Codec<PendingTransfer> {
  const $PendingTransferCodec();

  @override
  void encodeTo(PendingTransfer obj, _i1.Output output) {
    const _i1.U8ArrayCodec(32).encodeTo(obj.from, output);
    const _i1.U8ArrayCodec(32).encodeTo(obj.to, output);
    const _i1.U8ArrayCodec(32).encodeTo(obj.guardian, output);
    const _i1.OptionCodec<int>(_i1.U32Codec.codec).encodeTo(obj.assetId, output);
    _i1.U128Codec.codec.encodeTo(obj.amount, output);
  }

  @override
  PendingTransfer decode(_i1.Input input) {
    return PendingTransfer(
      from: const _i1.U8ArrayCodec(32).decode(input),
      to: const _i1.U8ArrayCodec(32).decode(input),
      guardian: const _i1.U8ArrayCodec(32).decode(input),
      assetId: const _i1.OptionCodec<int>(_i1.U32Codec.codec).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  @override
  int sizeHint(PendingTransfer obj) {
    int size = 0;
    size = size + const _i2.AccountId32Codec().sizeHint(obj.from);
    size = size + const _i2.AccountId32Codec().sizeHint(obj.to);
    size = size + const _i2.AccountId32Codec().sizeHint(obj.guardian);
    size = size + const _i1.OptionCodec<int>(_i1.U32Codec.codec).sizeHint(obj.assetId);
    size = size + _i1.U128Codec.codec.sizeHint(obj.amount);
    return size;
  }
}
