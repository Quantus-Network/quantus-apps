// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i3;

/// The `Event` enum of this pallet
abstract class Event {
  const Event();

  factory Event.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $EventCodec codec = $EventCodec();

  static const $Event values = $Event();

  _i2.Uint8List encode() {
    final output = _i1.ByteOutput(codec.sizeHint(this));
    codec.encodeTo(this, output);
    return output.toBytes();
  }

  int sizeHint() {
    return codec.sizeHint(this);
  }

  Map<String, Map<String, dynamic>> toJson();
}

class $Event {
  const $Event();

  NativeTransferred nativeTransferred({
    required _i3.AccountId32 from,
    required _i3.AccountId32 to,
    required BigInt amount,
    required BigInt transferCount,
    required BigInt leafIndex,
  }) {
    return NativeTransferred(from: from, to: to, amount: amount, transferCount: transferCount, leafIndex: leafIndex);
  }

  AssetTransferred assetTransferred({
    required int assetId,
    required _i3.AccountId32 from,
    required _i3.AccountId32 to,
    required BigInt amount,
    required BigInt transferCount,
    required BigInt leafIndex,
  }) {
    return AssetTransferred(
      assetId: assetId,
      from: from,
      to: to,
      amount: amount,
      transferCount: transferCount,
      leafIndex: leafIndex,
    );
  }

  ProofVerified proofVerified({required BigInt exitAmount, required List<List<int>> nullifiers}) {
    return ProofVerified(exitAmount: exitAmount, nullifiers: nullifiers);
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return NativeTransferred._decode(input);
      case 1:
        return AssetTransferred._decode(input);
      case 2:
        return ProofVerified._decode(input);
      default:
        throw Exception('Event: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Event value, _i1.Output output) {
    switch (value.runtimeType) {
      case NativeTransferred:
        (value as NativeTransferred).encodeTo(output);
        break;
      case AssetTransferred:
        (value as AssetTransferred).encodeTo(output);
        break;
      case ProofVerified:
        (value as ProofVerified).encodeTo(output);
        break;
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case NativeTransferred:
        return (value as NativeTransferred)._sizeHint();
      case AssetTransferred:
        return (value as AssetTransferred)._sizeHint();
      case ProofVerified:
        return (value as ProofVerified)._sizeHint();
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A native token transfer was recorded.
///
/// The `leaf_index` can be used to fetch Merkle proofs via the
/// `zkTrie_getMerkleProof` RPC for ZK circuit verification.
class NativeTransferred extends Event {
  const NativeTransferred({
    required this.from,
    required this.to,
    required this.amount,
    required this.transferCount,
    required this.leafIndex,
  });

  factory NativeTransferred._decode(_i1.Input input) {
    return NativeTransferred(
      from: const _i1.U8ArrayCodec(32).decode(input),
      to: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      transferCount: _i1.U64Codec.codec.decode(input),
      leafIndex: _i1.U64Codec.codec.decode(input),
    );
  }

  /// <T as frame_system::Config>::AccountId
  final _i3.AccountId32 from;

  /// <T as frame_system::Config>::AccountId
  final _i3.AccountId32 to;

  /// BalanceOf<T>
  final BigInt amount;

  /// T::TransferCount
  final BigInt transferCount;

  /// u64
  /// Index of this transfer in the ZK trie (for Merkle proof lookup)
  final BigInt leafIndex;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'NativeTransferred': {
      'from': from.toList(),
      'to': to.toList(),
      'amount': amount,
      'transferCount': transferCount,
      'leafIndex': leafIndex,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(from);
    size = size + const _i3.AccountId32Codec().sizeHint(to);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    size = size + _i1.U64Codec.codec.sizeHint(transferCount);
    size = size + _i1.U64Codec.codec.sizeHint(leafIndex);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    const _i1.U8ArrayCodec(32).encodeTo(from, output);
    const _i1.U8ArrayCodec(32).encodeTo(to, output);
    _i1.U128Codec.codec.encodeTo(amount, output);
    _i1.U64Codec.codec.encodeTo(transferCount, output);
    _i1.U64Codec.codec.encodeTo(leafIndex, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeTransferred &&
          _i4.listsEqual(other.from, from) &&
          _i4.listsEqual(other.to, to) &&
          other.amount == amount &&
          other.transferCount == transferCount &&
          other.leafIndex == leafIndex;

  @override
  int get hashCode => Object.hash(from, to, amount, transferCount, leafIndex);
}

/// A non-native asset transfer was recorded.
///
/// The `leaf_index` can be used to fetch Merkle proofs via the
/// `zkTrie_getMerkleProof` RPC for ZK circuit verification.
class AssetTransferred extends Event {
  const AssetTransferred({
    required this.assetId,
    required this.from,
    required this.to,
    required this.amount,
    required this.transferCount,
    required this.leafIndex,
  });

  factory AssetTransferred._decode(_i1.Input input) {
    return AssetTransferred(
      assetId: _i1.U32Codec.codec.decode(input),
      from: const _i1.U8ArrayCodec(32).decode(input),
      to: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      transferCount: _i1.U64Codec.codec.decode(input),
      leafIndex: _i1.U64Codec.codec.decode(input),
    );
  }

  /// T::AssetId
  final int assetId;

  /// <T as frame_system::Config>::AccountId
  final _i3.AccountId32 from;

  /// <T as frame_system::Config>::AccountId
  final _i3.AccountId32 to;

  /// AssetBalanceOf<T>
  final BigInt amount;

  /// T::TransferCount
  final BigInt transferCount;

  /// u64
  /// Index of this transfer in the ZK trie (for Merkle proof lookup)
  final BigInt leafIndex;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'AssetTransferred': {
      'assetId': assetId,
      'from': from.toList(),
      'to': to.toList(),
      'amount': amount,
      'transferCount': transferCount,
      'leafIndex': leafIndex,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(assetId);
    size = size + const _i3.AccountId32Codec().sizeHint(from);
    size = size + const _i3.AccountId32Codec().sizeHint(to);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    size = size + _i1.U64Codec.codec.sizeHint(transferCount);
    size = size + _i1.U64Codec.codec.sizeHint(leafIndex);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    _i1.U32Codec.codec.encodeTo(assetId, output);
    const _i1.U8ArrayCodec(32).encodeTo(from, output);
    const _i1.U8ArrayCodec(32).encodeTo(to, output);
    _i1.U128Codec.codec.encodeTo(amount, output);
    _i1.U64Codec.codec.encodeTo(transferCount, output);
    _i1.U64Codec.codec.encodeTo(leafIndex, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetTransferred &&
          other.assetId == assetId &&
          _i4.listsEqual(other.from, from) &&
          _i4.listsEqual(other.to, to) &&
          other.amount == amount &&
          other.transferCount == transferCount &&
          other.leafIndex == leafIndex;

  @override
  int get hashCode => Object.hash(assetId, from, to, amount, transferCount, leafIndex);
}

class ProofVerified extends Event {
  const ProofVerified({required this.exitAmount, required this.nullifiers});

  factory ProofVerified._decode(_i1.Input input) {
    return ProofVerified(
      exitAmount: _i1.U128Codec.codec.decode(input),
      nullifiers: const _i1.SequenceCodec<List<int>>(_i1.U8ArrayCodec(32)).decode(input),
    );
  }

  /// BalanceOf<T>
  final BigInt exitAmount;

  /// Vec<[u8; 32]>
  final List<List<int>> nullifiers;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'ProofVerified': {'exitAmount': exitAmount, 'nullifiers': nullifiers.map((value) => value.toList()).toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U128Codec.codec.sizeHint(exitAmount);
    size = size + const _i1.SequenceCodec<List<int>>(_i1.U8ArrayCodec(32)).sizeHint(nullifiers);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    _i1.U128Codec.codec.encodeTo(exitAmount, output);
    const _i1.SequenceCodec<List<int>>(_i1.U8ArrayCodec(32)).encodeTo(nullifiers, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProofVerified && other.exitAmount == exitAmount && _i4.listsEqual(other.nullifiers, nullifiers);

  @override
  int get hashCode => Object.hash(exitAmount, nullifiers);
}
