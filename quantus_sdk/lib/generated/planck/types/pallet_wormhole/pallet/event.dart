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

  MinerVolumeFeePaid minerVolumeFeePaid({required _i3.AccountId32 miner, required BigInt amount}) {
    return MinerVolumeFeePaid(miner: miner, amount: amount);
  }

  SegmentsDenied segmentsDenied({required List<int> indices}) {
    return SegmentsDenied(indices: indices);
  }

  ExitMintFailed exitMintFailed({required _i3.AccountId32 account, required BigInt amount}) {
    return ExitMintFailed(account: account, amount: amount);
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
      case 3:
        return MinerVolumeFeePaid._decode(input);
      case 4:
        return SegmentsDenied._decode(input);
      case 5:
        return ExitMintFailed._decode(input);
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
      case MinerVolumeFeePaid:
        (value as MinerVolumeFeePaid).encodeTo(output);
        break;
      case SegmentsDenied:
        (value as SegmentsDenied).encodeTo(output);
        break;
      case ExitMintFailed:
        (value as ExitMintFailed).encodeTo(output);
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
      case MinerVolumeFeePaid:
        return (value as MinerVolumeFeePaid)._sizeHint();
      case SegmentsDenied:
        return (value as SegmentsDenied)._sizeHint();
      case ExitMintFailed:
        return (value as ExitMintFailed)._sizeHint();
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

/// The block author's share of the wormhole exit volume fee was minted.
///
/// NOTE: keep this as the last variant — indexers decode events by their
/// position in this enum, so existing variants must never be reordered.
class MinerVolumeFeePaid extends Event {
  const MinerVolumeFeePaid({required this.miner, required this.amount});

  factory MinerVolumeFeePaid._decode(_i1.Input input) {
    return MinerVolumeFeePaid(
      miner: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// <T as frame_system::Config>::AccountId
  final _i3.AccountId32 miner;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'MinerVolumeFeePaid': {'miner': miner.toList(), 'amount': amount},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(miner);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(3, output);
    const _i1.U8ArrayCodec(32).encodeTo(miner, output);
    _i1.U128Codec.codec.encodeTo(amount, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinerVolumeFeePaid && _i4.listsEqual(other.miner, miner) && other.amount == amount;

  @override
  int get hashCode => Object.hash(miner, amount);
}

/// Some segments of an exit bundle were denied (their nullifiers were already
/// used, e.g. because the underlying private batch landed on-chain separately).
/// The remaining segments were processed normally.
class SegmentsDenied extends Event {
  const SegmentsDenied({required this.indices});

  factory SegmentsDenied._decode(_i1.Input input) {
    return SegmentsDenied(indices: _i1.U32SequenceCodec.codec.decode(input));
  }

  /// Vec<u32>
  final List<int> indices;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'SegmentsDenied': {'indices': indices},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32SequenceCodec.codec.sizeHint(indices);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(4, output);
    _i1.U32SequenceCodec.codec.encodeTo(indices, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SegmentsDenied && _i4.listsEqual(other.indices, indices);

  @override
  int get hashCode => indices.hashCode;
}

/// An exit slot could not be minted (e.g. a below-existential-deposit credit to
/// a fresh account) and was skipped so the rest of the bundle still processed.
/// The skipped exit's nullifier stays marked, so this exit cannot be retried.
///
/// NOTE: keep new variants appended at the end — indexers decode events by their
/// position in this enum, so existing variants must never be reordered.
class ExitMintFailed extends Event {
  const ExitMintFailed({required this.account, required this.amount});

  factory ExitMintFailed._decode(_i1.Input input) {
    return ExitMintFailed(account: const _i1.U8ArrayCodec(32).decode(input), amount: _i1.U128Codec.codec.decode(input));
  }

  /// <T as frame_system::Config>::AccountId
  final _i3.AccountId32 account;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'ExitMintFailed': {'account': account.toList(), 'amount': amount},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(account);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(5, output);
    const _i1.U8ArrayCodec(32).encodeTo(account, output);
    _i1.U128Codec.codec.encodeTo(amount, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExitMintFailed && _i4.listsEqual(other.account, account) && other.amount == amount;

  @override
  int get hashCode => Object.hash(account, amount);
}
