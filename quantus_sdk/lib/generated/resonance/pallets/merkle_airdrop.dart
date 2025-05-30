// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:typed_data' as _i5;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/frame_support/pallet_id.dart' as _i8;
import '../types/pallet_merkle_airdrop/pallet/call.dart' as _i7;
import '../types/resonance_runtime/runtime_call.dart' as _i6;
import '../types/sp_core/crypto/account_id32.dart' as _i3;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<int, List<int>> _airdropMerkleRoots =
      const _i1.StorageMap<int, List<int>>(
    prefix: 'MerkleAirdrop',
    storage: 'AirdropMerkleRoots',
    valueCodec: _i2.U8ArrayCodec(32),
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageMap<int, _i3.AccountId32> _airdropCreators =
      const _i1.StorageMap<int, _i3.AccountId32>(
    prefix: 'MerkleAirdrop',
    storage: 'AirdropCreators',
    valueCodec: _i3.AccountId32Codec(),
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageMap<int, BigInt> _airdropBalances =
      const _i1.StorageMap<int, BigInt>(
    prefix: 'MerkleAirdrop',
    storage: 'AirdropBalances',
    valueCodec: _i2.U128Codec.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageDoubleMap<int, _i3.AccountId32, dynamic> _claimed =
      const _i1.StorageDoubleMap<int, _i3.AccountId32, dynamic>(
    prefix: 'MerkleAirdrop',
    storage: 'Claimed',
    valueCodec: _i2.NullCodec.codec,
    hasher1: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
    hasher2: _i1.StorageHasher.blake2b128Concat(_i3.AccountId32Codec()),
  );

  final _i1.StorageValue<int> _nextAirdropId = const _i1.StorageValue<int>(
    prefix: 'MerkleAirdrop',
    storage: 'NextAirdropId',
    valueCodec: _i2.U32Codec.codec,
  );

  /// Storage for Merkle roots of each airdrop
  _i4.Future<List<int>?> airdropMerkleRoots(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _airdropMerkleRoots.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _airdropMerkleRoots.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Storage for airdrop creators
  _i4.Future<_i3.AccountId32?> airdropCreators(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _airdropCreators.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _airdropCreators.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Storage for airdrop balances
  _i4.Future<BigInt> airdropBalances(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _airdropBalances.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _airdropBalances.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  /// Storage for claimed status
  _i4.Future<dynamic> claimed(
    int key1,
    _i3.AccountId32 key2, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _claimed.hashedKeyFor(
      key1,
      key2,
    );
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _claimed.decodeValue(bytes);
    }
    return null; /* Default */
  }

  /// Counter for airdrop IDs
  _i4.Future<int> nextAirdropId({_i1.BlockHash? at}) async {
    final hashedKey = _nextAirdropId.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _nextAirdropId.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Returns the storage key for `airdropMerkleRoots`.
  _i5.Uint8List airdropMerkleRootsKey(int key1) {
    final hashedKey = _airdropMerkleRoots.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `airdropCreators`.
  _i5.Uint8List airdropCreatorsKey(int key1) {
    final hashedKey = _airdropCreators.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `airdropBalances`.
  _i5.Uint8List airdropBalancesKey(int key1) {
    final hashedKey = _airdropBalances.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `claimed`.
  _i5.Uint8List claimedKey(
    int key1,
    _i3.AccountId32 key2,
  ) {
    final hashedKey = _claimed.hashedKeyFor(
      key1,
      key2,
    );
    return hashedKey;
  }

  /// Returns the storage key for `nextAirdropId`.
  _i5.Uint8List nextAirdropIdKey() {
    final hashedKey = _nextAirdropId.hashedKey();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `airdropMerkleRoots`.
  _i5.Uint8List airdropMerkleRootsMapPrefix() {
    final hashedKey = _airdropMerkleRoots.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `airdropCreators`.
  _i5.Uint8List airdropCreatorsMapPrefix() {
    final hashedKey = _airdropCreators.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `airdropBalances`.
  _i5.Uint8List airdropBalancesMapPrefix() {
    final hashedKey = _airdropBalances.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `claimed`.
  _i5.Uint8List claimedMapPrefix(int key1) {
    final hashedKey = _claimed.mapPrefix(key1);
    return hashedKey;
  }
}

class Txs {
  const Txs();

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
  _i6.MerkleAirdrop createAirdrop({required List<int> merkleRoot}) {
    return _i6.MerkleAirdrop(_i7.CreateAirdrop(merkleRoot: merkleRoot));
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
  _i6.MerkleAirdrop fundAirdrop({
    required int airdropId,
    required BigInt amount,
  }) {
    return _i6.MerkleAirdrop(_i7.FundAirdrop(
      airdropId: airdropId,
      amount: amount,
    ));
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
  _i6.MerkleAirdrop claim({
    required int airdropId,
    required _i3.AccountId32 recipient,
    required BigInt amount,
    required List<List<int>> merkleProof,
  }) {
    return _i6.MerkleAirdrop(_i7.Claim(
      airdropId: airdropId,
      recipient: recipient,
      amount: amount,
      merkleProof: merkleProof,
    ));
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
  _i6.MerkleAirdrop deleteAirdrop({required int airdropId}) {
    return _i6.MerkleAirdrop(_i7.DeleteAirdrop(airdropId: airdropId));
  }
}

class Constants {
  Constants();

  /// The maximum number of proof elements allowed in a Merkle proof.
  final int maxProofs = 100;

  /// The pallet id, used for deriving its sovereign account ID.
  final _i8.PalletId palletId = const <int>[
    97,
    105,
    114,
    100,
    114,
    111,
    112,
    33,
  ];

  /// Priority for unsigned claim transactions.
  final BigInt unsignedClaimPriority = BigInt.from(100);
}
