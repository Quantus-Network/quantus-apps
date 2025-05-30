// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i8;
import 'dart:typed_data' as _i9;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i5;

import '../types/pallet_reversible_transfers/delay_policy.dart' as _i4;
import '../types/pallet_reversible_transfers/pallet/call.dart' as _i11;
import '../types/pallet_reversible_transfers/pending_transfer.dart' as _i7;
import '../types/primitive_types/h256.dart' as _i6;
import '../types/resonance_runtime/runtime_call.dart' as _i10;
import '../types/sp_core/crypto/account_id32.dart' as _i2;
import '../types/sp_runtime/multiaddress/multi_address.dart' as _i12;
import '../types/tuples.dart' as _i3;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.AccountId32, _i3.Tuple2<int, _i4.DelayPolicy>>
      _reversibleAccounts =
      const _i1.StorageMap<_i2.AccountId32, _i3.Tuple2<int, _i4.DelayPolicy>>(
    prefix: 'ReversibleTransfers',
    storage: 'ReversibleAccounts',
    valueCodec: _i3.Tuple2Codec<int, _i4.DelayPolicy>(
      _i5.U32Codec.codec,
      _i4.DelayPolicy.codec,
    ),
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageMap<_i6.H256, _i7.PendingTransfer> _pendingTransfers =
      const _i1.StorageMap<_i6.H256, _i7.PendingTransfer>(
    prefix: 'ReversibleTransfers',
    storage: 'PendingTransfers',
    valueCodec: _i7.PendingTransfer.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i6.H256Codec()),
  );

  final _i1.StorageMap<_i2.AccountId32, int> _accountPendingIndex =
      const _i1.StorageMap<_i2.AccountId32, int>(
    prefix: 'ReversibleTransfers',
    storage: 'AccountPendingIndex',
    valueCodec: _i5.U32Codec.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  /// Maps accounts to their chosen reversibility delay period (in milliseconds).
  /// Accounts present in this map have reversibility enabled.
  _i8.Future<_i3.Tuple2<int, _i4.DelayPolicy>?> reversibleAccounts(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _reversibleAccounts.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _reversibleAccounts.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Stores the details of pending transactions scheduled for delayed execution.
  /// Keyed by the unique transaction ID.
  _i8.Future<_i7.PendingTransfer?> pendingTransfers(
    _i6.H256 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _pendingTransfers.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _pendingTransfers.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Indexes pending transaction IDs per account for efficient lookup and cancellation.
  /// Also enforces the maximum pending transactions limit per account.
  _i8.Future<int> accountPendingIndex(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _accountPendingIndex.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _accountPendingIndex.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Returns the storage key for `reversibleAccounts`.
  _i9.Uint8List reversibleAccountsKey(_i2.AccountId32 key1) {
    final hashedKey = _reversibleAccounts.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `pendingTransfers`.
  _i9.Uint8List pendingTransfersKey(_i6.H256 key1) {
    final hashedKey = _pendingTransfers.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `accountPendingIndex`.
  _i9.Uint8List accountPendingIndexKey(_i2.AccountId32 key1) {
    final hashedKey = _accountPendingIndex.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `reversibleAccounts`.
  _i9.Uint8List reversibleAccountsMapPrefix() {
    final hashedKey = _reversibleAccounts.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `pendingTransfers`.
  _i9.Uint8List pendingTransfersMapPrefix() {
    final hashedKey = _pendingTransfers.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `accountPendingIndex`.
  _i9.Uint8List accountPendingIndexMapPrefix() {
    final hashedKey = _accountPendingIndex.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Enable reversibility for the calling account with a specified delay, or disable it.
  ///
  /// - `delay`: The time (in milliseconds) after submission before the transaction executes.
  ///  If `None`, reversibility is disabled for the account.
  ///  If `Some`, must be >= `MinDelayPeriod`.
  _i10.ReversibleTransfers setReversibility({
    int? delay,
    required _i4.DelayPolicy policy,
  }) {
    return _i10.ReversibleTransfers(_i11.SetReversibility(
      delay: delay,
      policy: policy,
    ));
  }

  /// Cancel a pending reversible transaction scheduled by the caller.
  ///
  /// - `tx_id`: The unique identifier of the transaction to cancel.
  _i10.ReversibleTransfers cancel({required _i6.H256 txId}) {
    return _i10.ReversibleTransfers(_i11.Cancel(txId: txId));
  }

  /// Called by the Scheduler to finalize the scheduled task/call
  ///
  /// - `tx_id`: The unique id of the transaction to finalize and dispatch.
  _i10.ReversibleTransfers executeTransfer({required _i6.H256 txId}) {
    return _i10.ReversibleTransfers(_i11.ExecuteTransfer(txId: txId));
  }

  /// Schedule a transaction for delayed execution.
  _i10.ReversibleTransfers scheduleTransfer({
    required _i12.MultiAddress dest,
    required BigInt amount,
  }) {
    return _i10.ReversibleTransfers(_i11.ScheduleTransfer(
      dest: dest,
      amount: amount,
    ));
  }
}

class Constants {
  Constants();

  /// Maximum pending reversible transactions allowed per account. Used for BoundedVec.
  final int maxPendingPerAccount = 10;

  /// The default delay period for reversible transactions if none is specified.
  final int defaultDelay = 10;

  /// The minimum delay period allowed for reversible transactions.
  final int minDelayPeriod = 2;
}
