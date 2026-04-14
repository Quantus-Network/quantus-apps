// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../bounded_collections/bounded_btree_map/bounded_b_tree_map.dart' as _i3;
import '../sp_core/crypto/account_id32.dart' as _i2;
import '../tuples.dart' as _i6;

class MultisigData {
  const MultisigData({
    required this.creator,
    required this.signers,
    required this.threshold,
    required this.proposalNonce,
    required this.deposit,
    required this.activeProposals,
    required this.proposalsPerSigner,
  });

  factory MultisigData.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// AccountId
  final _i2.AccountId32 creator;

  /// BoundedSigners
  final List<_i2.AccountId32> signers;

  /// u32
  final int threshold;

  /// u32
  final int proposalNonce;

  /// Balance
  final BigInt deposit;

  /// u32
  final int activeProposals;

  /// BoundedProposalsPerSigner
  final _i3.BoundedBTreeMap proposalsPerSigner;

  static const $MultisigDataCodec codec = $MultisigDataCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
    'creator': creator.toList(),
    'signers': signers.map((value) => value.toList()).toList(),
    'threshold': threshold,
    'proposalNonce': proposalNonce,
    'deposit': deposit,
    'activeProposals': activeProposals,
    'proposalsPerSigner': proposalsPerSigner.map((value) => [value.value0.toList(), value.value1]).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MultisigData &&
          _i5.listsEqual(other.creator, creator) &&
          _i5.listsEqual(other.signers, signers) &&
          other.threshold == threshold &&
          other.proposalNonce == proposalNonce &&
          other.deposit == deposit &&
          other.activeProposals == activeProposals &&
          other.proposalsPerSigner == proposalsPerSigner;

  @override
  int get hashCode =>
      Object.hash(creator, signers, threshold, proposalNonce, deposit, activeProposals, proposalsPerSigner);
}

class $MultisigDataCodec with _i1.Codec<MultisigData> {
  const $MultisigDataCodec();

  @override
  void encodeTo(MultisigData obj, _i1.Output output) {
    const _i1.U8ArrayCodec(32).encodeTo(obj.creator, output);
    const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec()).encodeTo(obj.signers, output);
    _i1.U32Codec.codec.encodeTo(obj.threshold, output);
    _i1.U32Codec.codec.encodeTo(obj.proposalNonce, output);
    _i1.U128Codec.codec.encodeTo(obj.deposit, output);
    _i1.U32Codec.codec.encodeTo(obj.activeProposals, output);
    const _i1.SequenceCodec<_i6.Tuple2<_i2.AccountId32, int>>(
      _i6.Tuple2Codec<_i2.AccountId32, int>(_i2.AccountId32Codec(), _i1.U32Codec.codec),
    ).encodeTo(obj.proposalsPerSigner, output);
  }

  @override
  MultisigData decode(_i1.Input input) {
    return MultisigData(
      creator: const _i1.U8ArrayCodec(32).decode(input),
      signers: const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec()).decode(input),
      threshold: _i1.U32Codec.codec.decode(input),
      proposalNonce: _i1.U32Codec.codec.decode(input),
      deposit: _i1.U128Codec.codec.decode(input),
      activeProposals: _i1.U32Codec.codec.decode(input),
      proposalsPerSigner: const _i1.SequenceCodec<_i6.Tuple2<_i2.AccountId32, int>>(
        _i6.Tuple2Codec<_i2.AccountId32, int>(_i2.AccountId32Codec(), _i1.U32Codec.codec),
      ).decode(input),
    );
  }

  @override
  int sizeHint(MultisigData obj) {
    int size = 0;
    size = size + const _i2.AccountId32Codec().sizeHint(obj.creator);
    size = size + const _i1.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec()).sizeHint(obj.signers);
    size = size + _i1.U32Codec.codec.sizeHint(obj.threshold);
    size = size + _i1.U32Codec.codec.sizeHint(obj.proposalNonce);
    size = size + _i1.U128Codec.codec.sizeHint(obj.deposit);
    size = size + _i1.U32Codec.codec.sizeHint(obj.activeProposals);
    size = size + const _i3.BoundedBTreeMapCodec().sizeHint(obj.proposalsPerSigner);
    return size;
  }
}
