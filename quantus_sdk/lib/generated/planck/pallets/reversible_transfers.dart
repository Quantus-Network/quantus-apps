// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i7;
import 'dart:typed_data' as _i8;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i6;

import '../types/pallet_reversible_transfers/high_security_account_data.dart' as _i3;
import '../types/pallet_reversible_transfers/pallet/call.dart' as _i11;
import '../types/pallet_reversible_transfers/pending_transfer.dart' as _i5;
import '../types/primitive_types/h256.dart' as _i4;
import '../types/qp_scheduler/block_number_or_timestamp.dart' as _i10;
import '../types/quantus_runtime/runtime_call.dart' as _i9;
import '../types/sp_arithmetic/per_things/permill.dart' as _i13;
import '../types/sp_core/crypto/account_id32.dart' as _i2;
import '../types/sp_runtime/multiaddress/multi_address.dart' as _i12;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.AccountId32, _i3.HighSecurityAccountData> _highSecurityAccounts =
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

  final _i1.StorageMap<_i2.AccountId32, List<_i4.H256>> _pendingTransfersBySender =
      const _i1.StorageMap<_i2.AccountId32, List<_i4.H256>>(
        prefix: 'ReversibleTransfers',
        storage: 'PendingTransfersBySender',
        valueCodec: _i6.SequenceCodec<_i4.H256>(_i4.H256Codec()),
        hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
      );

  final _i1.StorageMap<_i2.AccountId32, List<_i2.AccountId32>> _guardianIndex =
      const _i1.StorageMap<_i2.AccountId32, List<_i2.AccountId32>>(
        prefix: 'ReversibleTransfers',
        storage: 'GuardianIndex',
        valueCodec: _i6.SequenceCodec<_i2.AccountId32>(_i2.AccountId32Codec()),
        hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
      );

  final _i1.StorageValue<BigInt> _nextTransactionId = const _i1.StorageValue<BigInt>(
    prefix: 'ReversibleTransfers',
    storage: 'NextTransactionId',
    valueCodec: _i6.U64Codec.codec,
  );

  /// Maps accounts to their chosen reversibility delay period (in milliseconds).
  /// Accounts present in this map have reversibility enabled.
  _i7.Future<_i3.HighSecurityAccountData?> highSecurityAccounts(_i2.AccountId32 key1, {_i1.BlockHash? at}) async {
    final hashedKey = _highSecurityAccounts.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _highSecurityAccounts.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Stores the details of pending transactions scheduled for delayed execution.
  /// Keyed by the unique transaction ID.
  _i7.Future<_i5.PendingTransfer?> pendingTransfers(_i4.H256 key1, {_i1.BlockHash? at}) async {
    final hashedKey = _pendingTransfers.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _pendingTransfers.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Maps sender accounts to their list of pending transaction IDs.
  _i7.Future<List<_i4.H256>> pendingTransfersBySender(_i2.AccountId32 key1, {_i1.BlockHash? at}) async {
    final hashedKey = _pendingTransfersBySender.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _pendingTransfersBySender.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// Maps guardian accounts to the list of accounts they protect.
  /// This allows the UI to efficiently query all accounts for which a given account is a
  /// guardian.
  _i7.Future<List<_i2.AccountId32>> guardianIndex(_i2.AccountId32 key1, {_i1.BlockHash? at}) async {
    final hashedKey = _guardianIndex.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _guardianIndex.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// Monotonically increasing counter used to generate unique transaction IDs.
  /// Each scheduled transfer increments this value to ensure no two transfers
  /// produce the same `tx_id`, even if they have identical parameters.
  _i7.Future<BigInt> nextTransactionId({_i1.BlockHash? at}) async {
    final hashedKey = _nextTransactionId.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _nextTransactionId.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  /// Maps accounts to their chosen reversibility delay period (in milliseconds).
  /// Accounts present in this map have reversibility enabled.
  _i7.Future<List<_i3.HighSecurityAccountData?>> multiHighSecurityAccounts(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys.map((key) => _highSecurityAccounts.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _highSecurityAccounts.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// Stores the details of pending transactions scheduled for delayed execution.
  /// Keyed by the unique transaction ID.
  _i7.Future<List<_i5.PendingTransfer?>> multiPendingTransfers(List<_i4.H256> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _pendingTransfers.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _pendingTransfers.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// Maps sender accounts to their list of pending transaction IDs.
  _i7.Future<List<List<_i4.H256>>> multiPendingTransfersBySender(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys.map((key) => _pendingTransfersBySender.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _pendingTransfersBySender.decodeValue(v.key)).toList();
    }
    return (keys.map((key) => []).toList() as List<List<_i4.H256>>); /* Default */
  }

  /// Maps guardian accounts to the list of accounts they protect.
  /// This allows the UI to efficiently query all accounts for which a given account is a
  /// guardian.
  _i7.Future<List<List<_i2.AccountId32>>> multiGuardianIndex(List<_i2.AccountId32> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _guardianIndex.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _guardianIndex.decodeValue(v.key)).toList();
    }
    return (keys.map((key) => []).toList() as List<List<_i2.AccountId32>>); /* Default */
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

  /// Returns the storage key for `pendingTransfersBySender`.
  _i8.Uint8List pendingTransfersBySenderKey(_i2.AccountId32 key1) {
    final hashedKey = _pendingTransfersBySender.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `guardianIndex`.
  _i8.Uint8List guardianIndexKey(_i2.AccountId32 key1) {
    final hashedKey = _guardianIndex.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `nextTransactionId`.
  _i8.Uint8List nextTransactionIdKey() {
    final hashedKey = _nextTransactionId.hashedKey();
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

  /// Returns the storage map key prefix for `pendingTransfersBySender`.
  _i8.Uint8List pendingTransfersBySenderMapPrefix() {
    final hashedKey = _pendingTransfersBySender.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `guardianIndex`.
  _i8.Uint8List guardianIndexMapPrefix() {
    final hashedKey = _guardianIndex.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Enable high-security for the calling account with a specified
  /// reversibility delay.
  ///
  /// Once an account is set as high security it can only make reversible
  /// transfers. It is not allowed any other calls.
  ///
  /// # Warning: Permanent and Irreversible
  ///
  /// **Enabling high security mode is a one-way operation that cannot be undone.**
  ///
  /// Once this function is called successfully, the account is permanently restricted
  /// to only the following operations:
  /// - [`schedule_transfer`](Self::schedule_transfer) - Schedule delayed native token
  ///  transfers
  /// - [`schedule_asset_transfer`](Self::schedule_asset_transfer) - Schedule delayed asset
  ///  transfers
  /// - [`cancel`](Self::cancel) - Cancel pending transfers
  /// - [`recover_funds`](Self::recover_funds) - Guardian-initiated emergency fund recovery
  ///
  /// There is no mechanism to disable high security mode or restore normal account
  /// functionality. This design is intentional to provide maximum security guarantees:
  /// an attacker who gains access to the account cannot simply disable the protections.
  ///
  /// Users who no longer wish to use high-security features can simply transfer their
  /// funds to a different account using [`schedule_transfer`](Self::schedule_transfer)
  /// or [`schedule_asset_transfer`](Self::schedule_asset_transfer).
  ///
  /// # Parameters
  ///
  /// - `delay`: The reversibility time for any transfer made by the high-security account.
  /// - `guardian`: The guardian account that can cancel pending transfers and recover funds
  ///  from this high-security account.
  _i9.ReversibleTransfers setHighSecurity({
    required _i10.BlockNumberOrTimestamp delay,
    required _i2.AccountId32 guardian,
  }) {
    return _i9.ReversibleTransfers(_i11.SetHighSecurity(delay: delay, guardian: guardian));
  }

  /// Cancel a pending reversible transaction scheduled by the caller.
  ///
  /// - `tx_id`: The unique identifier of the transaction to cancel.
  _i9.ReversibleTransfers cancel({required _i4.H256 txId}) {
    return _i9.ReversibleTransfers(_i11.Cancel(txId: txId));
  }

  /// Executes a previously scheduled transfer after the delay period has elapsed.
  ///
  /// This extrinsic is called automatically by the Scheduler pallet when the
  /// delay period expires. It must be signed by this pallet's account (not a user).
  /// The pallet account is set as the origin when scheduling via
  /// [`do_schedule_transfer_inner`](Self::do_schedule_transfer_inner).
  ///
  /// # Parameters
  ///
  /// - `tx_id`: The unique identifier of the pending transfer to execute.
  ///
  /// # Errors
  ///
  /// - [`InvalidSchedulerOrigin`](Error::InvalidSchedulerOrigin): Called by an account other
  ///  than this pallet's account.
  /// - [`PendingTxNotFound`](Error::PendingTxNotFound): No pending transfer with this ID.
  _i9.ReversibleTransfers executeTransfer({required _i4.H256 txId}) {
    return _i9.ReversibleTransfers(_i11.ExecuteTransfer(txId: txId));
  }

  /// Schedule a transaction for delayed execution.
  _i9.ReversibleTransfers scheduleTransfer({required _i12.MultiAddress dest, required BigInt amount}) {
    return _i9.ReversibleTransfers(_i11.ScheduleTransfer(dest: dest, amount: amount));
  }

  /// Schedule a transaction for delayed execution with a custom, one-time delay.
  ///
  /// This can only be used by accounts that have *not* set up a persistent
  /// reversibility configuration with `set_high_security`.
  ///
  /// - `delay`: The time (in blocks or milliseconds) before the transaction executes.
  _i9.ReversibleTransfers scheduleTransferWithDelay({
    required _i12.MultiAddress dest,
    required BigInt amount,
    required _i10.BlockNumberOrTimestamp delay,
  }) {
    return _i9.ReversibleTransfers(_i11.ScheduleTransferWithDelay(dest: dest, amount: amount, delay: delay));
  }

  /// Schedule an asset transfer (pallet-assets) for delayed execution using the configured
  /// delay.
  _i9.ReversibleTransfers scheduleAssetTransfer({
    required int assetId,
    required _i12.MultiAddress dest,
    required BigInt amount,
  }) {
    return _i9.ReversibleTransfers(_i11.ScheduleAssetTransfer(assetId: assetId, dest: dest, amount: amount));
  }

  /// Schedule an asset transfer (pallet-assets) with a custom one-time delay.
  _i9.ReversibleTransfers scheduleAssetTransferWithDelay({
    required int assetId,
    required _i12.MultiAddress dest,
    required BigInt amount,
    required _i10.BlockNumberOrTimestamp delay,
  }) {
    return _i9.ReversibleTransfers(
      _i11.ScheduleAssetTransferWithDelay(assetId: assetId, dest: dest, amount: amount, delay: delay),
    );
  }

  /// Allows the guardian to recover all funds from a high-security account
  /// by transferring the entire balance to themselves.
  ///
  /// This is an emergency function for when the high-security account may be compromised.
  /// It cancels all pending transfers first (applying volume fees), then transfers
  /// the remaining free balance to the guardian.
  ///
  /// If releasing held funds fails for any transfer, that transfer is skipped (metadata
  /// preserved for manual retry via `cancel`) and a `TransferRecoveryFailed` event is
  /// emitted. Other transfers continue to be processed.
  _i9.ReversibleTransfers recoverFunds({required _i2.AccountId32 account}) {
    return _i9.ReversibleTransfers(_i11.RecoverFunds(account: account));
  }
}

class Constants {
  Constants();

  /// Maximum number of accounts a single guardian can protect. Used for BoundedVec.
  final int maxGuardianAccounts = 32;

  /// Maximum pending reversible transactions allowed per account.
  final int maxPendingPerAccount = 16;

  /// The default delay period for reversible transactions if none is specified.
  ///
  /// NOTE: default delay is always in blocks.
  final _i10.BlockNumberOrTimestamp defaultDelay = const _i10.BlockNumber(7200);

  /// The minimum delay period allowed for reversible transactions, in blocks.
  final int minDelayPeriodBlocks = 2;

  /// The minimum delay period allowed for reversible transactions, in milliseconds.
  final BigInt minDelayPeriodMoment = BigInt.from(12000);

  /// Volume fee taken from reversed transactions for high-security accounts only,
  /// expressed as a Permill (e.g., Permill::from_percent(1) = 1%). Regular accounts incur no
  /// fees. The fee is burned (removed from total issuance).
  final _i13.Permill volumeFee = 10000;
}
