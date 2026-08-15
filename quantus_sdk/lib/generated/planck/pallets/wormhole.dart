// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:typed_data' as _i5;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/pallet_wormhole/pallet/call.dart' as _i7;
import '../types/quantus_runtime/runtime_call.dart' as _i6;
import '../types/sp_arithmetic/per_things/permill.dart' as _i8;
import '../types/sp_core/crypto/account_id32.dart' as _i3;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<List<int>, bool> _usedNullifiers = const _i1.StorageMap<List<int>, bool>(
    prefix: 'Wormhole',
    storage: 'UsedNullifiers',
    valueCodec: _i2.BoolCodec.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U8ArrayCodec(32)),
  );

  final _i1.StorageMap<_i3.AccountId32, BigInt> _transferCount = const _i1.StorageMap<_i3.AccountId32, BigInt>(
    prefix: 'Wormhole',
    storage: 'TransferCount',
    valueCodec: _i2.U64Codec.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i3.AccountId32Codec()),
  );

  _i4.Future<bool> usedNullifiers(List<int> key1, {_i1.BlockHash? at}) async {
    final hashedKey = _usedNullifiers.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _usedNullifiers.decodeValue(bytes);
    }
    return false; /* Default */
  }

  /// Transfer count per recipient - used to generate unique leaf indices in the ZK trie.
  ///
  /// Keyed on the *canonical* recipient (each 8-byte limb reduced mod the Goldilocks
  /// prime, matching the ZK leaf encoding — see `canonical_leaf_recipient`), so that a
  /// recipient and its non-canonical byte aliases share one count sequence and two
  /// distinct deposits can never commit to identical leaves.
  _i4.Future<BigInt> transferCount(_i3.AccountId32 key1, {_i1.BlockHash? at}) async {
    final hashedKey = _transferCount.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _transferCount.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  _i4.Future<List<bool>> multiUsedNullifiers(List<List<int>> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _usedNullifiers.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _usedNullifiers.decodeValue(v.key)).toList();
    }
    return (keys.map((key) => false).toList() as List<bool>); /* Default */
  }

  /// Transfer count per recipient - used to generate unique leaf indices in the ZK trie.
  ///
  /// Keyed on the *canonical* recipient (each 8-byte limb reduced mod the Goldilocks
  /// prime, matching the ZK leaf encoding — see `canonical_leaf_recipient`), so that a
  /// recipient and its non-canonical byte aliases share one count sequence and two
  /// distinct deposits can never commit to identical leaves.
  _i4.Future<List<BigInt>> multiTransferCount(List<_i3.AccountId32> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _transferCount.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _transferCount.decodeValue(v.key)).toList();
    }
    return (keys.map((key) => BigInt.zero).toList() as List<BigInt>); /* Default */
  }

  /// Returns the storage key for `usedNullifiers`.
  _i5.Uint8List usedNullifiersKey(List<int> key1) {
    final hashedKey = _usedNullifiers.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `transferCount`.
  _i5.Uint8List transferCountKey(_i3.AccountId32 key1) {
    final hashedKey = _transferCount.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `usedNullifiers`.
  _i5.Uint8List usedNullifiersMapPrefix() {
    final hashedKey = _usedNullifiers.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `transferCount`.
  _i5.Uint8List transferCountMapPrefix() {
    final hashedKey = _transferCount.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Verify a private-batch wormhole proof and process all exits in the batch.
  ///
  /// Returns `DispatchResultWithPostInfo` to allow weight correction on early failures.
  /// If validation fails before ZK verification, we return minimal weight.
  /// If ZK verification fails, we return full weight since the work was done.
  _i6.Wormhole verifyPrivateBatch({required List<int> proofBytes}) {
    return _i6.Wormhole(_i7.VerifyPrivateBatch(proofBytes: proofBytes));
  }

  /// Verify a public-batch wormhole proof and process all valid exit segments.
  ///
  /// Invalid segments (already-spent nullifiers) are denied individually; dummy-padded
  /// segments (all-zero nullifiers) are skipped silently. A portion of the burn bucket
  /// is minted to the proof's `aggregator_address`; if that mint fails (e.g. the
  /// account doesn't exist and the rebate is below the existential deposit) the
  /// rebate is burned instead of failing the users' exits.
  _i6.Wormhole verifyPublicBatch({required List<int> proofBytes}) {
    return _i6.Wormhole(_i7.VerifyPublicBatch(proofBytes: proofBytes));
  }
}

class Constants {
  Constants();

  /// Account ID used as the "from" account when creating transfer proofs for minted tokens
  final _i3.AccountId32 mintingAccount = const <int>[
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
    1,
  ];

  /// Volume fee rate in basis points (1 basis point = 0.01%).
  /// This must match the fee rate used in proof generation.
  final int volumeFeeRateBps = 4;

  /// Proportion of volume fees to burn (not mint). The remainder goes to the block author.
  /// Example: Permill::from_percent(50) means 50% burned, 50% to miner.
  final _i8.Permill volumeFeesBurnRate = 500000;

  /// For public-batch proofs, the proportion of the burn bucket redirected to the
  /// aggregator instead of being destroyed. The miner's share is unchanged.
  /// Example: Permill::from_percent(50) means half the burn portion goes to the aggregator.
  final _i8.Permill volumeFeesAggregatorRate = 500000;
}
