// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../sp_core/crypto/account_id32.dart' as _i2;

class AirdropMetadata {
  const AirdropMetadata({
    required this.merkleRoot,
    required this.creator,
    required this.balance,
    this.vestingPeriod,
    this.vestingDelay,
  });

  factory AirdropMetadata.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// MerkleHash
  final List<int> merkleRoot;

  /// AccountId
  final _i2.AccountId32 creator;

  /// Balance
  final BigInt balance;

  /// Option<BlockNumber>
  final int? vestingPeriod;

  /// Option<BlockNumber>
  final int? vestingDelay;

  static const $AirdropMetadataCodec codec = $AirdropMetadataCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'merkleRoot': merkleRoot.toList(),
        'creator': creator.toList(),
        'balance': balance,
        'vestingPeriod': vestingPeriod,
        'vestingDelay': vestingDelay,
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is AirdropMetadata &&
          _i4.listsEqual(
            other.merkleRoot,
            merkleRoot,
          ) &&
          _i4.listsEqual(
            other.creator,
            creator,
          ) &&
          other.balance == balance &&
          other.vestingPeriod == vestingPeriod &&
          other.vestingDelay == vestingDelay;

  @override
  int get hashCode => Object.hash(
        merkleRoot,
        creator,
        balance,
        vestingPeriod,
        vestingDelay,
      );
}

class $AirdropMetadataCodec with _i1.Codec<AirdropMetadata> {
  const $AirdropMetadataCodec();

  @override
  void encodeTo(
    AirdropMetadata obj,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.merkleRoot,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.creator,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      obj.balance,
      output,
    );
    const _i1.OptionCodec<int>(_i1.U32Codec.codec).encodeTo(
      obj.vestingPeriod,
      output,
    );
    const _i1.OptionCodec<int>(_i1.U32Codec.codec).encodeTo(
      obj.vestingDelay,
      output,
    );
  }

  @override
  AirdropMetadata decode(_i1.Input input) {
    return AirdropMetadata(
      merkleRoot: const _i1.U8ArrayCodec(32).decode(input),
      creator: const _i1.U8ArrayCodec(32).decode(input),
      balance: _i1.U128Codec.codec.decode(input),
      vestingPeriod:
          const _i1.OptionCodec<int>(_i1.U32Codec.codec).decode(input),
      vestingDelay:
          const _i1.OptionCodec<int>(_i1.U32Codec.codec).decode(input),
    );
  }

  @override
  int sizeHint(AirdropMetadata obj) {
    int size = 0;
    size = size + const _i1.U8ArrayCodec(32).sizeHint(obj.merkleRoot);
    size = size + const _i2.AccountId32Codec().sizeHint(obj.creator);
    size = size + _i1.U128Codec.codec.sizeHint(obj.balance);
    size = size +
        const _i1.OptionCodec<int>(_i1.U32Codec.codec)
            .sizeHint(obj.vestingPeriod);
    size = size +
        const _i1.OptionCodec<int>(_i1.U32Codec.codec)
            .sizeHint(obj.vestingDelay);
    return size;
  }
}
