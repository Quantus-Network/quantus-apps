// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i6;

import 'package:polkadart/polkadart.dart' as _i1;

import '../types/pallet_recovery/active_recovery.dart' as _i4;
import '../types/pallet_recovery/pallet/call.dart' as _i9;
import '../types/pallet_recovery/recovery_config.dart' as _i3;
import '../types/quantus_runtime/runtime_call.dart' as _i7;
import '../types/sp_core/crypto/account_id32.dart' as _i2;
import '../types/sp_runtime/multiaddress/multi_address.dart' as _i8;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.AccountId32, _i3.RecoveryConfig> _recoverable =
      const _i1.StorageMap<_i2.AccountId32, _i3.RecoveryConfig>(
    prefix: 'Recovery',
    storage: 'Recoverable',
    valueCodec: _i3.RecoveryConfig.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.AccountId32Codec()),
  );

  final _i1
      .StorageDoubleMap<_i2.AccountId32, _i2.AccountId32, _i4.ActiveRecovery>
      _activeRecoveries = const _i1.StorageDoubleMap<_i2.AccountId32,
          _i2.AccountId32, _i4.ActiveRecovery>(
    prefix: 'Recovery',
    storage: 'ActiveRecoveries',
    valueCodec: _i4.ActiveRecovery.codec,
    hasher1: _i1.StorageHasher.twoxx64Concat(_i2.AccountId32Codec()),
    hasher2: _i1.StorageHasher.twoxx64Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageMap<_i2.AccountId32, _i2.AccountId32> _proxy =
      const _i1.StorageMap<_i2.AccountId32, _i2.AccountId32>(
    prefix: 'Recovery',
    storage: 'Proxy',
    valueCodec: _i2.AccountId32Codec(),
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
  );

  /// The set of recoverable accounts and their recovery configuration.
  _i5.Future<_i3.RecoveryConfig?> recoverable(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _recoverable.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _recoverable.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Active recovery attempts.
  ///
  /// First account is the account to be recovered, and the second account
  /// is the user trying to recover the account.
  _i5.Future<_i4.ActiveRecovery?> activeRecoveries(
    _i2.AccountId32 key1,
    _i2.AccountId32 key2, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _activeRecoveries.hashedKeyFor(
      key1,
      key2,
    );
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _activeRecoveries.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The list of allowed proxy accounts.
  ///
  /// Map from the user who can access it to the recovered account.
  _i5.Future<_i2.AccountId32?> proxy(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _proxy.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _proxy.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The set of recoverable accounts and their recovery configuration.
  _i5.Future<List<_i3.RecoveryConfig?>> multiRecoverable(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _recoverable.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _recoverable.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// The list of allowed proxy accounts.
  ///
  /// Map from the user who can access it to the recovered account.
  _i5.Future<List<_i2.AccountId32?>> multiProxy(
    List<_i2.AccountId32> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys.map((key) => _proxy.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _proxy.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `recoverable`.
  _i6.Uint8List recoverableKey(_i2.AccountId32 key1) {
    final hashedKey = _recoverable.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `activeRecoveries`.
  _i6.Uint8List activeRecoveriesKey(
    _i2.AccountId32 key1,
    _i2.AccountId32 key2,
  ) {
    final hashedKey = _activeRecoveries.hashedKeyFor(
      key1,
      key2,
    );
    return hashedKey;
  }

  /// Returns the storage key for `proxy`.
  _i6.Uint8List proxyKey(_i2.AccountId32 key1) {
    final hashedKey = _proxy.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `recoverable`.
  _i6.Uint8List recoverableMapPrefix() {
    final hashedKey = _recoverable.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `activeRecoveries`.
  _i6.Uint8List activeRecoveriesMapPrefix(_i2.AccountId32 key1) {
    final hashedKey = _activeRecoveries.mapPrefix(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `proxy`.
  _i6.Uint8List proxyMapPrefix() {
    final hashedKey = _proxy.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Send a call through a recovered account.
  ///
  /// The dispatch origin for this call must be _Signed_ and registered to
  /// be able to make calls on behalf of the recovered account.
  ///
  /// Parameters:
  /// - `account`: The recovered account you want to make a call on-behalf-of.
  /// - `call`: The call you want to make with the recovered account.
  _i7.Recovery asRecovered({
    required _i8.MultiAddress account,
    required _i7.RuntimeCall call,
  }) {
    return _i7.Recovery(_i9.AsRecovered(
      account: account,
      call: call,
    ));
  }

  /// Allow ROOT to bypass the recovery process and set an a rescuer account
  /// for a lost account directly.
  ///
  /// The dispatch origin for this call must be _ROOT_.
  ///
  /// Parameters:
  /// - `lost`: The "lost account" to be recovered.
  /// - `rescuer`: The "rescuer account" which can call as the lost account.
  _i7.Recovery setRecovered({
    required _i8.MultiAddress lost,
    required _i8.MultiAddress rescuer,
  }) {
    return _i7.Recovery(_i9.SetRecovered(
      lost: lost,
      rescuer: rescuer,
    ));
  }

  /// Create a recovery configuration for your account. This makes your account recoverable.
  ///
  /// Payment: `ConfigDepositBase` + `FriendDepositFactor` * #_of_friends balance
  /// will be reserved for storing the recovery configuration. This deposit is returned
  /// in full when the user calls `remove_recovery`.
  ///
  /// The dispatch origin for this call must be _Signed_.
  ///
  /// Parameters:
  /// - `friends`: A list of friends you trust to vouch for recovery attempts. Should be
  ///  ordered and contain no duplicate values.
  /// - `threshold`: The number of friends that must vouch for a recovery attempt before the
  ///  account can be recovered. Should be less than or equal to the length of the list of
  ///  friends.
  /// - `delay_period`: The number of blocks after a recovery attempt is initialized that
  ///  needs to pass before the account can be recovered.
  _i7.Recovery createRecovery({
    required List<_i2.AccountId32> friends,
    required int threshold,
    required int delayPeriod,
  }) {
    return _i7.Recovery(_i9.CreateRecovery(
      friends: friends,
      threshold: threshold,
      delayPeriod: delayPeriod,
    ));
  }

  /// Initiate the process for recovering a recoverable account.
  ///
  /// Payment: `RecoveryDeposit` balance will be reserved for initiating the
  /// recovery process. This deposit will always be repatriated to the account
  /// trying to be recovered. See `close_recovery`.
  ///
  /// The dispatch origin for this call must be _Signed_.
  ///
  /// Parameters:
  /// - `account`: The lost account that you want to recover. This account needs to be
  ///  recoverable (i.e. have a recovery configuration).
  _i7.Recovery initiateRecovery({required _i8.MultiAddress account}) {
    return _i7.Recovery(_i9.InitiateRecovery(account: account));
  }

  /// Allow a "friend" of a recoverable account to vouch for an active recovery
  /// process for that account.
  ///
  /// The dispatch origin for this call must be _Signed_ and must be a "friend"
  /// for the recoverable account.
  ///
  /// Parameters:
  /// - `lost`: The lost account that you want to recover.
  /// - `rescuer`: The account trying to rescue the lost account that you want to vouch for.
  ///
  /// The combination of these two parameters must point to an active recovery
  /// process.
  _i7.Recovery vouchRecovery({
    required _i8.MultiAddress lost,
    required _i8.MultiAddress rescuer,
  }) {
    return _i7.Recovery(_i9.VouchRecovery(
      lost: lost,
      rescuer: rescuer,
    ));
  }

  /// Allow a successful rescuer to claim their recovered account.
  ///
  /// The dispatch origin for this call must be _Signed_ and must be a "rescuer"
  /// who has successfully completed the account recovery process: collected
  /// `threshold` or more vouches, waited `delay_period` blocks since initiation.
  ///
  /// Parameters:
  /// - `account`: The lost account that you want to claim has been successfully recovered by
  ///  you.
  _i7.Recovery claimRecovery({required _i8.MultiAddress account}) {
    return _i7.Recovery(_i9.ClaimRecovery(account: account));
  }

  /// As the controller of a recoverable account, close an active recovery
  /// process for your account.
  ///
  /// Payment: By calling this function, the recoverable account will receive
  /// the recovery deposit `RecoveryDeposit` placed by the rescuer.
  ///
  /// The dispatch origin for this call must be _Signed_ and must be a
  /// recoverable account with an active recovery process for it.
  ///
  /// Parameters:
  /// - `rescuer`: The account trying to rescue this recoverable account.
  _i7.Recovery closeRecovery({required _i8.MultiAddress rescuer}) {
    return _i7.Recovery(_i9.CloseRecovery(rescuer: rescuer));
  }

  /// Remove the recovery process for your account. Recovered accounts are still accessible.
  ///
  /// NOTE: The user must make sure to call `close_recovery` on all active
  /// recovery attempts before calling this function else it will fail.
  ///
  /// Payment: By calling this function the recoverable account will unreserve
  /// their recovery configuration deposit.
  /// (`ConfigDepositBase` + `FriendDepositFactor` * #_of_friends)
  ///
  /// The dispatch origin for this call must be _Signed_ and must be a
  /// recoverable account (i.e. has a recovery configuration).
  _i7.Recovery removeRecovery() {
    return _i7.Recovery(_i9.RemoveRecovery());
  }

  /// Cancel the ability to use `as_recovered` for `account`.
  ///
  /// The dispatch origin for this call must be _Signed_ and registered to
  /// be able to make calls on behalf of the recovered account.
  ///
  /// Parameters:
  /// - `account`: The recovered account you are able to call on-behalf-of.
  _i7.Recovery cancelRecovered({required _i8.MultiAddress account}) {
    return _i7.Recovery(_i9.CancelRecovered(account: account));
  }
}

class Constants {
  Constants();

  /// The base amount of currency needed to reserve for creating a recovery configuration.
  ///
  /// This is held for an additional storage item whose value size is
  /// `2 + sizeof(BlockNumber, Balance)` bytes.
  final BigInt configDepositBase = BigInt.from(10000000000000);

  /// The amount of currency needed per additional user when creating a recovery
  /// configuration.
  ///
  /// This is held for adding `sizeof(AccountId)` bytes more into a pre-existing storage
  /// value.
  final BigInt friendDepositFactor = BigInt.from(1000000000000);

  /// The maximum amount of friends allowed in a recovery configuration.
  ///
  /// NOTE: The threshold programmed in this Pallet uses u16, so it does
  /// not really make sense to have a limit here greater than u16::MAX.
  /// But also, that is a lot more than you should probably set this value
  /// to anyway...
  final int maxFriends = 9;

  /// The base amount of currency needed to reserve for starting a recovery.
  ///
  /// This is primarily held for deterring malicious recovery attempts, and should
  /// have a value large enough that a bad actor would choose not to place this
  /// deposit. It also acts to fund additional storage item whose value size is
  /// `sizeof(BlockNumber, Balance + T * AccountId)` bytes. Where T is a configurable
  /// threshold.
  final BigInt recoveryDeposit = BigInt.from(10000000000000);
}
