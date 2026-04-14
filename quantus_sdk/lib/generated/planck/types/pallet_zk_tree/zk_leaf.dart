// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../sp_core/crypto/account_id32.dart' as _i2;

class ZkLeaf {
  const ZkLeaf({required this.to, required this.transferCount, required this.assetId, required this.amount});

  factory ZkLeaf.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// AccountId
  final _i2.AccountId32 to;

  /// u64
  final BigInt transferCount;

  /// AssetId
  final int assetId;

  /// Balance
  final BigInt amount;

  static const $ZkLeafCodec codec = $ZkLeafCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
    'to': to.toList(),
    'transferCount': transferCount,
    'assetId': assetId,
    'amount': amount,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZkLeaf &&
          _i4.listsEqual(other.to, to) &&
          other.transferCount == transferCount &&
          other.assetId == assetId &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(to, transferCount, assetId, amount);
}

class $ZkLeafCodec with _i1.Codec<ZkLeaf> {
  const $ZkLeafCodec();

  @override
  void encodeTo(ZkLeaf obj, _i1.Output output) {
    const _i1.U8ArrayCodec(32).encodeTo(obj.to, output);
    _i1.U64Codec.codec.encodeTo(obj.transferCount, output);
    _i1.U32Codec.codec.encodeTo(obj.assetId, output);
    _i1.U128Codec.codec.encodeTo(obj.amount, output);
  }

  @override
  ZkLeaf decode(_i1.Input input) {
    return ZkLeaf(
      to: const _i1.U8ArrayCodec(32).decode(input),
      transferCount: _i1.U64Codec.codec.decode(input),
      assetId: _i1.U32Codec.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  @override
  int sizeHint(ZkLeaf obj) {
    int size = 0;
    size = size + const _i2.AccountId32Codec().sizeHint(obj.to);
    size = size + _i1.U64Codec.codec.sizeHint(obj.transferCount);
    size = size + _i1.U32Codec.codec.sizeHint(obj.assetId);
    size = size + _i1.U128Codec.codec.sizeHint(obj.amount);
    return size;
  }
}
