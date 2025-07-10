// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i7;
import 'dart:typed_data' as _i8;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i6;

import '../types/pallet_reversible_transfers/high_security_account_data.dart'
    as _i3;
import '../types/pallet_reversible_transfers/pallet/call.dart' as _i11;
import '../types/pallet_reversible_transfers/pending_transfer.dart' as _i5;
import '../types/primitive_types/h256.dart' as _i4;
import '../types/qp_scheduler/block_number_or_timestamp.dart' as _i10;
import '../types/quantus_runtime/runtime_call.dart' as _i9;
import '../types/sp_core/crypto/account_id32.dart' as _i2;
import '../types/sp_runtime/multiaddress/multi_address.dart' as _i12;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.AccountId32, _i3.HighSecurityAccountData>
      _highSecurityAccounts =
      const _i1.StorageMap<_i2.AccountId32, _i3.HighSecurityAccountData>(
    prefix: 'ReversibleTransfers',
    storage: 'HighSecurityAccounts',
    valueCodec: _i3.HighSecurityAccountData.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageMap<_i4.H256, _i5.PendingTransfer> _pendingTransfers =
      const _i1.StorageMap<_i4.H256, _i5.PendingTransfer>(
    prefix: 'ReversibleTransfers',
    storage: 'PendingTransfers',
    valueCodec: _i5.PendingTransfer.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i4.H256Codec()),
  );

  final _i1.StorageMap<_i2.AccountId32, int> _accountPendingIndex =
      const _i1.StorageMap<_i2.AccountId32, int>(
    prefix: 'ReversibleTransfers',
    storage: 'AccountPendingIndex',
    valueCodec: _i6.U32Codec.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageMap<_i2.AccountId32, List<_i4.H256>>
      _pendingTransfersBySender =
      const _i1.StorageMap<_i2.AccountId32, List<_i4.H256>>(
    prefix: 'ReversibleTransfers',
    storage: 'PendingTransfersBySender',
    valueCodec: _i6.SequenceCodec<_i4.H256>(_i4.H256Codec()),
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageMap<_i2.AccountId32, List<_i4.H256>>
      _pendingTransfersByRecipient =
      const _i1.StorageMap<_i2.AccountId32, List<_i4.H256>>(
    prefix: 'ReversibleTransfers',
    storage: 'PendingTransfersByRecipient',
    valueCodec: _i6.SequenceCodec<_i4.H256>(_i4.H256Codec()),
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageMap<_i2.AccountId32, List<_i2.AccountId32>>
      _interceptorIndex =
      const _i1.StorageMap<_i2.AccountId32, List<_i2.AccountId32>>(
    prefix: 'ReversibleTransfers',
    storage: 'InterceptorIndex',
    valueCodec: _i6.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec()),
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageValue<BigInt> _globalNonce = const _i1.StorageValue<BigInt>(
    prefix: 'ReversibleTransfers',
    storage: 'GlobalNonce',
    valueCodec: _i6.U64Codec.codec,
  );

  /// Maps accounts to their chosen reversibility delay period (in milliseconds).
  /// Accounts present in this map have reversibility enabled.
  _i7.Future<_i3.HighSecurityAccountData?> highSecurityAccounts(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _highSecurityAccounts.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _highSecurityAccounts.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Stores the details of pending transactions scheduled for delayed execution.
  /// Keyed by the unique transaction ID.
  _i7.Future<_i5.PendingTransfer?> pendingTransfers(
    _i4.H256 key1, {
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
  _i7.Future<int> accountPendingIndex(
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

  /// Maps sender accounts to their list of pending transaction IDs.
  /// This allows users to query all their outgoing pending transfers.
  _i7.Future<List<_i4.H256>> pendingTransfersBySender(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _pendingTransfersBySender.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _pendingTransfersBySender.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// Maps recipient accounts to their list of pending incoming transaction IDs.
  /// This allows users to query all their incoming pending transfers.
  _i7.Future<List<_i4.H256>> pendingTransfersByRecipient(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _pendingTransfersByRecipient.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _pendingTransfersByRecipient.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// Maps interceptor accounts to the list of accounts they can intercept for.
  /// This allows the UI to efficiently query all accounts for which a given account is an interceptor.
  _i7.Future<List<_i2.AccountId32>> interceptorIndex(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _interceptorIndex.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _interceptorIndex.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// Global nonce for generating unique transaction IDs.
  _i7.Future<BigInt> globalNonce({_i1.BlockHash? at}) async {
    final hashedKey = _globalNonce.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _globalNonce.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  /// Maps accounts to their chosen reversibility delay period (in milliseconds).
  /// Accounts present in this map have reversibility enabled.
  _i7.Future<List<_i3.HighSecurityAccountData?>> multiHighSecurityAccounts(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _highSecurityAccounts.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _highSecurityAccounts.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// Stores the details of pending transactions scheduled for delayed execution.
  /// Keyed by the unique transaction ID.
  _i7.Future<List<_i5.PendingTransfer?>> multiPendingTransfers(
    List<_i4.H256> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _pendingTransfers.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _pendingTransfers.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// Indexes pending transaction IDs per account for efficient lookup and cancellation.
  /// Also enforces the maximum pending transactions limit per account.
  _i7.Future<List<int>> multiAccountPendingIndex(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _accountPendingIndex.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _accountPendingIndex.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => 0).toList() as List<int>); /* Default */
  }

  /// Maps sender accounts to their list of pending transaction IDs.
  /// This allows users to query all their outgoing pending transfers.
  _i7.Future<List<List<_i4.H256>>> multiPendingTransfersBySender(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _pendingTransfersBySender.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _pendingTransfersBySender.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => []).toList()
        as List<List<_i4.H256>>); /* Default */
  }

  /// Maps recipient accounts to their list of pending incoming transaction IDs.
  /// This allows users to query all their incoming pending transfers.
  _i7.Future<List<List<_i4.H256>>> multiPendingTransfersByRecipient(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys
        .map((key) => _pendingTransfersByRecipient.hashedKeyFor(key))
        .toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _pendingTransfersByRecipient.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => []).toList()
        as List<List<_i4.H256>>); /* Default */
  }

  /// Maps interceptor accounts to the list of accounts they can intercept for.
  /// This allows the UI to efficiently query all accounts for which a given account is an interceptor.
  _i7.Future<List<List<_i2.AccountId32>>> multiInterceptorIndex(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _interceptorIndex.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _interceptorIndex.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => []).toList()
        as List<List<_i2.AccountId32>>); /* Default */
  }

  /// Returns the storage key for `highSecurityAccounts`.
  _i8.Uint8List highSecurityAccountsKey(_i2.AccountId32 key1) {
    final hashedKey = _highSecurityAccounts.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `pendingTransfers`.
  _i8.Uint8List pendingTransfersKey(_i4.H256 key1) {
    final hashedKey = _pendingTransfers.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `accountPendingIndex`.
  _i8.Uint8List accountPendingIndexKey(_i2.AccountId32 key1) {
    final hashedKey = _accountPendingIndex.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `pendingTransfersBySender`.
  _i8.Uint8List pendingTransfersBySenderKey(_i2.AccountId32 key1) {
    final hashedKey = _pendingTransfersBySender.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `pendingTransfersByRecipient`.
  _i8.Uint8List pendingTransfersByRecipientKey(_i2.AccountId32 key1) {
    final hashedKey = _pendingTransfersByRecipient.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `interceptorIndex`.
  _i8.Uint8List interceptorIndexKey(_i2.AccountId32 key1) {
    final hashedKey = _interceptorIndex.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `globalNonce`.
  _i8.Uint8List globalNonceKey() {
    final hashedKey = _globalNonce.hashedKey();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `highSecurityAccounts`.
  _i8.Uint8List highSecurityAccountsMapPrefix() {
    final hashedKey = _highSecurityAccounts.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `pendingTransfers`.
  _i8.Uint8List pendingTransfersMapPrefix() {
    final hashedKey = _pendingTransfers.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `accountPendingIndex`.
  _i8.Uint8List accountPendingIndexMapPrefix() {
    final hashedKey = _accountPendingIndex.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `pendingTransfersBySender`.
  _i8.Uint8List pendingTransfersBySenderMapPrefix() {
    final hashedKey = _pendingTransfersBySender.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `pendingTransfersByRecipient`.
  _i8.Uint8List pendingTransfersByRecipientMapPrefix() {
    final hashedKey = _pendingTransfersByRecipient.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `interceptorIndex`.
  _i8.Uint8List interceptorIndexMapPrefix() {
    final hashedKey = _interceptorIndex.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Enable high-security for the calling account with a specified delay
  ///
  /// - `delay`: The time (in milliseconds) after submission before the transaction executes.
  _i9.ReversibleTransfers setHighSecurity({
    required _i10.BlockNumberOrTimestamp delay,
    required _i2.AccountId32 interceptor,
    required _i2.AccountId32 recoverer,
  }) {
    return _i9.ReversibleTransfers(_i11.SetHighSecurity(
      delay: delay,
      interceptor: interceptor,
      recoverer: recoverer,
    ));
  }

  /// Cancel a pending reversible transaction scheduled by the caller.
  ///
  /// - `tx_id`: The unique identifier of the transaction to cancel.
  _i9.ReversibleTransfers cancel({required _i4.H256 txId}) {
    return _i9.ReversibleTransfers(_i11.Cancel(txId: txId));
  }

  /// Called by the Scheduler to finalize the scheduled task/call
  ///
  /// - `tx_id`: The unique id of the transaction to finalize and dispatch.
  _i9.ReversibleTransfers executeTransfer({required _i4.H256 txId}) {
    return _i9.ReversibleTransfers(_i11.ExecuteTransfer(txId: txId));
  }

  /// Schedule a transaction for delayed execution.
  _i9.ReversibleTransfers scheduleTransfer({
    required _i12.MultiAddress dest,
    required BigInt amount,
  }) {
    return _i9.ReversibleTransfers(_i11.ScheduleTransfer(
      dest: dest,
      amount: amount,
    ));
  }

  /// Schedule a transaction for delayed execution with a custom, one-time delay.
  ///
  /// This can only be used by accounts that have *not* set up a persistent
  /// reversibility configuration with `set_reversibility`.
  ///
  /// - `delay`: The time (in blocks or milliseconds) before the transaction executes.
  _i9.ReversibleTransfers scheduleTransferWithDelay({
    required _i12.MultiAddress dest,
    required BigInt amount,
    required _i10.BlockNumberOrTimestamp delay,
  }) {
    return _i9.ReversibleTransfers(_i11.ScheduleTransferWithDelay(
      dest: dest,
      amount: amount,
      delay: delay,
    ));
  }
}

class Constants {
  Constants();

  /// Maximum pending reversible transactions allowed per account. Used for BoundedVec.
  final int maxPendingPerAccount = 10;

  /// Maximum number of accounts an interceptor can intercept for. Used for BoundedVec.
  final int maxInterceptorAccounts = 32;

  /// The default delay period for reversible transactions if none is specified.
  ///
  /// NOTE: default delay is always in blocks.
  final _i10.BlockNumberOrTimestamp defaultDelay =
      const _i10.BlockNumber(86400);

  /// The minimum delay period allowed for reversible transactions, in blocks.
  final int minDelayPeriodBlocks = 2;

  /// The minimum delay period allowed for reversible transactions, in milliseconds.
  final BigInt minDelayPeriodMoment = BigInt.from(10000);
}
