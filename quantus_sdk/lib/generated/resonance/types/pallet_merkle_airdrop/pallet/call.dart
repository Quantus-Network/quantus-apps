// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i3;

/// Contains a variant per dispatchable extrinsic that this pallet has.
abstract class Call {
  const Call();

  factory Call.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $CallCodec codec = $CallCodec();

  static const $Call values = $Call();

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

class $Call {
  const $Call();

  CreateAirdrop createAirdrop({
    required List<int> merkleRoot,
    int? vestingPeriod,
    int? vestingDelay,
  }) {
    return CreateAirdrop(
      merkleRoot: merkleRoot,
      vestingPeriod: vestingPeriod,
      vestingDelay: vestingDelay,
    );
  }

  FundAirdrop fundAirdrop({
    required int airdropId,
    required BigInt amount,
  }) {
    return FundAirdrop(
      airdropId: airdropId,
      amount: amount,
    );
  }

  Claim claim({
    required int airdropId,
    required _i3.AccountId32 recipient,
    required BigInt amount,
    required List<List<int>> merkleProof,
  }) {
    return Claim(
      airdropId: airdropId,
      recipient: recipient,
      amount: amount,
      merkleProof: merkleProof,
    );
  }

  DeleteAirdrop deleteAirdrop({required int airdropId}) {
    return DeleteAirdrop(airdropId: airdropId);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return CreateAirdrop._decode(input);
      case 1:
        return FundAirdrop._decode(input);
      case 2:
        return Claim._decode(input);
      case 3:
        return DeleteAirdrop._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Call value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case CreateAirdrop:
        (value as CreateAirdrop).encodeTo(output);
        break;
      case FundAirdrop:
        (value as FundAirdrop).encodeTo(output);
        break;
      case Claim:
        (value as Claim).encodeTo(output);
        break;
      case DeleteAirdrop:
        (value as DeleteAirdrop).encodeTo(output);
        break;
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case CreateAirdrop:
        return (value as CreateAirdrop)._sizeHint();
      case FundAirdrop:
        return (value as FundAirdrop)._sizeHint();
      case Claim:
        return (value as Claim)._sizeHint();
      case DeleteAirdrop:
        return (value as DeleteAirdrop)._sizeHint();
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Create a new airdrop with a Merkle root.
///
/// The Merkle root is a cryptographic hash that represents all valid claims
/// for this airdrop. Users will later provide Merkle proofs to verify their
/// eligibility to claim tokens.
///
/// # Parameters
///
/// * `origin` - The origin of the call (must be signed)
/// * `merkle_root` - The Merkle root hash representing all valid claims
/// * `vesting_period` - Optional vesting period for the airdrop
/// * `vesting_delay` - Optional delay before vesting starts
class CreateAirdrop extends Call {
  const CreateAirdrop({
    required this.merkleRoot,
    this.vestingPeriod,
    this.vestingDelay,
  });

  factory CreateAirdrop._decode(_i1.Input input) {
    return CreateAirdrop(
      merkleRoot: const _i1.U8ArrayCodec(32).decode(input),
      vestingPeriod:
          const _i1.OptionCodec<int>(_i1.U32Codec.codec).decode(input),
      vestingDelay:
          const _i1.OptionCodec<int>(_i1.U32Codec.codec).decode(input),
    );
  }

  /// MerkleRoot
  final List<int> merkleRoot;

  /// Option<BlockNumberFor<T>>
  final int? vestingPeriod;

  /// Option<BlockNumberFor<T>>
  final int? vestingDelay;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'create_airdrop': {
          'merkleRoot': merkleRoot.toList(),
          'vestingPeriod': vestingPeriod,
          'vestingDelay': vestingDelay,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i1.U8ArrayCodec(32).sizeHint(merkleRoot);
    size = size +
        const _i1.OptionCodec<int>(_i1.U32Codec.codec).sizeHint(vestingPeriod);
    size = size +
        const _i1.OptionCodec<int>(_i1.U32Codec.codec).sizeHint(vestingDelay);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      merkleRoot,
      output,
    );
    const _i1.OptionCodec<int>(_i1.U32Codec.codec).encodeTo(
      vestingPeriod,
      output,
    );
    const _i1.OptionCodec<int>(_i1.U32Codec.codec).encodeTo(
      vestingDelay,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CreateAirdrop &&
          _i4.listsEqual(
            other.merkleRoot,
            merkleRoot,
          ) &&
          other.vestingPeriod == vestingPeriod &&
          other.vestingDelay == vestingDelay;

  @override
  int get hashCode => Object.hash(
        merkleRoot,
        vestingPeriod,
        vestingDelay,
      );
}

/// Fund an existing airdrop with tokens.
///
/// This function transfers tokens from the caller to the airdrop's account,
/// making them available for users to claim.
///
/// # Parameters
///
/// * `origin` - The origin of the call (must be signed)
/// * `airdrop_id` - The ID of the airdrop to fund
/// * `amount` - The amount of tokens to add to the airdrop
///
/// # Errors
///
/// * `AirdropNotFound` - If the specified airdrop does not exist
class FundAirdrop extends Call {
  const FundAirdrop({
    required this.airdropId,
    required this.amount,
  });

  factory FundAirdrop._decode(_i1.Input input) {
    return FundAirdrop(
      airdropId: _i1.U32Codec.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// AirdropId
  final int airdropId;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'fund_airdrop': {
          'airdropId': airdropId,
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(airdropId);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      airdropId,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is FundAirdrop &&
          other.airdropId == airdropId &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        airdropId,
        amount,
      );
}

/// Claim tokens from an airdrop by providing a Merkle proof.
///
/// Users can claim their tokens by providing a proof of their eligibility.
/// The proof is verified against the airdrop's Merkle root.
/// Anyone can trigger a claim for any eligible recipient.
///
/// # Parameters
///
/// * `origin` - The origin of the call
/// * `airdrop_id` - The ID of the airdrop to claim from
/// * `amount` - The amount of tokens to claim
/// * `merkle_proof` - The Merkle proof verifying eligibility
///
/// # Errors
///
/// * `AirdropNotFound` - If the specified airdrop does not exist
/// * `AlreadyClaimed` - If the recipient has already claimed from this airdrop
/// * `InvalidProof` - If the provided Merkle proof is invalid
/// * `InsufficientAirdropBalance` - If the airdrop doesn't have enough tokens
class Claim extends Call {
  const Claim({
    required this.airdropId,
    required this.recipient,
    required this.amount,
    required this.merkleProof,
  });

  factory Claim._decode(_i1.Input input) {
    return Claim(
      airdropId: _i1.U32Codec.codec.decode(input),
      recipient: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      merkleProof: const _i1.SequenceCodec<List<int>>(_i1.U8ArrayCodec(32))
          .decode(input),
    );
  }

  /// AirdropId
  final int airdropId;

  /// T::AccountId
  final _i3.AccountId32 recipient;

  /// BalanceOf<T>
  final BigInt amount;

  /// BoundedVec<MerkleHash, T::MaxProofs>
  final List<List<int>> merkleProof;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'claim': {
          'airdropId': airdropId,
          'recipient': recipient.toList(),
          'amount': amount,
          'merkleProof': merkleProof.map((value) => value.toList()).toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(airdropId);
    size = size + const _i3.AccountId32Codec().sizeHint(recipient);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    size = size +
        const _i1.SequenceCodec<List<int>>(_i1.U8ArrayCodec(32))
            .sizeHint(merkleProof);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      airdropId,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      recipient,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
    const _i1.SequenceCodec<List<int>>(_i1.U8ArrayCodec(32)).encodeTo(
      merkleProof,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Claim &&
          other.airdropId == airdropId &&
          _i4.listsEqual(
            other.recipient,
            recipient,
          ) &&
          other.amount == amount &&
          _i4.listsEqual(
            other.merkleProof,
            merkleProof,
          );

  @override
  int get hashCode => Object.hash(
        airdropId,
        recipient,
        amount,
        merkleProof,
      );
}

/// Delete an airdrop and reclaim any remaining funds.
///
/// This function allows the creator of an airdrop to delete it and reclaim
/// any remaining tokens that haven't been claimed.
///
/// # Parameters
///
/// * `origin` - The origin of the call (must be the airdrop creator)
/// * `airdrop_id` - The ID of the airdrop to delete
///
/// # Errors
///
/// * `AirdropNotFound` - If the specified airdrop does not exist
/// * `NotAirdropCreator` - If the caller is not the creator of the airdrop
class DeleteAirdrop extends Call {
  const DeleteAirdrop({required this.airdropId});

  factory DeleteAirdrop._decode(_i1.Input input) {
    return DeleteAirdrop(airdropId: _i1.U32Codec.codec.decode(input));
  }

  /// AirdropId
  final int airdropId;

  @override
  Map<String, Map<String, int>> toJson() => {
        'delete_airdrop': {'airdropId': airdropId}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(airdropId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      airdropId,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is DeleteAirdrop && other.airdropId == airdropId;

  @override
  int get hashCode => airdropId.hashCode;
}
