// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i6;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i4;

import '../types/pallet_indices/pallet/call.dart' as _i8;
import '../types/polkadot_runtime/runtime_call.dart' as _i7;
import '../types/sp_core/crypto/account_id32.dart' as _i3;
import '../types/sp_runtime/multiaddress/multi_address.dart' as _i9;
import '../types/tuples.dart' as _i2;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<int, _i2.Tuple3<_i3.AccountId32, BigInt, bool>>
      _accounts =
      const _i1.StorageMap<int, _i2.Tuple3<_i3.AccountId32, BigInt, bool>>(
    prefix: 'Indices',
    storage: 'Accounts',
    valueCodec: _i2.Tuple3Codec<_i3.AccountId32, BigInt, bool>(
      _i3.AccountId32Codec(),
      _i4.U128Codec.codec,
      _i4.BoolCodec.codec,
    ),
    hasher: _i1.StorageHasher.blake2b128Concat(_i4.U32Codec.codec),
  );

  /// The lookup from index to account.
  _i5.Future<_i2.Tuple3<_i3.AccountId32, BigInt, bool>?> accounts(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _accounts.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _accounts.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The lookup from index to account.
  _i5.Future<List<_i2.Tuple3<_i3.AccountId32, BigInt, bool>?>> multiAccounts(
    List<int> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys.map((key) => _accounts.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _accounts.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `accounts`.
  _i6.Uint8List accountsKey(int key1) {
    final hashedKey = _accounts.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `accounts`.
  _i6.Uint8List accountsMapPrefix() {
    final hashedKey = _accounts.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Assign an previously unassigned index.
  ///
  /// Payment: `Deposit` is reserved from the sender account.
  ///
  /// The dispatch origin for this call must be _Signed_.
  ///
  /// - `index`: the index to be claimed. This must not be in use.
  ///
  /// Emits `IndexAssigned` if successful.
  ///
  /// ## Complexity
  /// - `O(1)`.
  _i7.Indices claim({required int index}) {
    return _i7.Indices(_i8.Claim(index: index));
  }

  /// Assign an index already owned by the sender to another account. The balance reservation
  /// is effectively transferred to the new account.
  ///
  /// The dispatch origin for this call must be _Signed_.
  ///
  /// - `index`: the index to be re-assigned. This must be owned by the sender.
  /// - `new`: the new owner of the index. This function is a no-op if it is equal to sender.
  ///
  /// Emits `IndexAssigned` if successful.
  ///
  /// ## Complexity
  /// - `O(1)`.
  _i7.Indices transfer({
    required _i9.MultiAddress new_,
    required int index,
  }) {
    return _i7.Indices(_i8.Transfer(
      new_: new_,
      index: index,
    ));
  }

  /// Free up an index owned by the sender.
  ///
  /// Payment: Any previous deposit placed for the index is unreserved in the sender account.
  ///
  /// The dispatch origin for this call must be _Signed_ and the sender must own the index.
  ///
  /// - `index`: the index to be freed. This must be owned by the sender.
  ///
  /// Emits `IndexFreed` if successful.
  ///
  /// ## Complexity
  /// - `O(1)`.
  _i7.Indices free({required int index}) {
    return _i7.Indices(_i8.Free(index: index));
  }

  /// Force an index to an account. This doesn't require a deposit. If the index is already
  /// held, then any deposit is reimbursed to its current owner.
  ///
  /// The dispatch origin for this call must be _Root_.
  ///
  /// - `index`: the index to be (re-)assigned.
  /// - `new`: the new owner of the index. This function is a no-op if it is equal to sender.
  /// - `freeze`: if set to `true`, will freeze the index so it cannot be transferred.
  ///
  /// Emits `IndexAssigned` if successful.
  ///
  /// ## Complexity
  /// - `O(1)`.
  _i7.Indices forceTransfer({
    required _i9.MultiAddress new_,
    required int index,
    required bool freeze,
  }) {
    return _i7.Indices(_i8.ForceTransfer(
      new_: new_,
      index: index,
      freeze: freeze,
    ));
  }

  /// Freeze an index so it will always point to the sender account. This consumes the
  /// deposit.
  ///
  /// The dispatch origin for this call must be _Signed_ and the signing account must have a
  /// non-frozen account `index`.
  ///
  /// - `index`: the index to be frozen in place.
  ///
  /// Emits `IndexFrozen` if successful.
  ///
  /// ## Complexity
  /// - `O(1)`.
  _i7.Indices freeze({required int index}) {
    return _i7.Indices(_i8.Freeze(index: index));
  }

  /// Poke the deposit reserved for an index.
  ///
  /// The dispatch origin for this call must be _Signed_ and the signing account must have a
  /// non-frozen account `index`.
  ///
  /// The transaction fees is waived if the deposit is changed after poking/reconsideration.
  ///
  /// - `index`: the index whose deposit is to be poked/reconsidered.
  ///
  /// Emits `DepositPoked` if successful.
  _i7.Indices pokeDeposit({required int index}) {
    return _i7.Indices(_i8.PokeDeposit(index: index));
  }
}

class Constants {
  Constants();

  /// The deposit needed for reserving an index.
  final BigInt deposit = BigInt.from(100000000000);
}
