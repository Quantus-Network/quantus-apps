// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:typed_data' as _i5;

import 'package:polkadart/polkadart.dart' as _i1;

import '../types/pallet_treasury/pallet/call.dart' as _i7;
import '../types/quantus_runtime/runtime_call.dart' as _i6;
import '../types/sp_arithmetic/per_things/permill.dart' as _i3;
import '../types/sp_core/crypto/account_id32.dart' as _i2;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<_i2.AccountId32> _treasuryAccount = const _i1.StorageValue<_i2.AccountId32>(
    prefix: 'TreasuryPallet',
    storage: 'TreasuryAccount',
    valueCodec: _i2.AccountId32Codec(),
  );

  final _i1.StorageValue<_i3.Permill> _treasuryPortion = const _i1.StorageValue<_i3.Permill>(
    prefix: 'TreasuryPallet',
    storage: 'TreasuryPortion',
    valueCodec: _i3.PermillCodec(),
  );

  /// The treasury account that receives mining rewards.
  _i4.Future<_i2.AccountId32?> treasuryAccount({_i1.BlockHash? at}) async {
    final hashedKey = _treasuryAccount.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _treasuryAccount.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The portion of mining rewards that goes to treasury (Permill, 0–100%).
  /// Uses OptionQuery so genesis is required. Permill allows fine granularity (e.g. 33.3%).
  _i4.Future<_i3.Permill?> treasuryPortion({_i1.BlockHash? at}) async {
    final hashedKey = _treasuryPortion.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _treasuryPortion.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Returns the storage key for `treasuryAccount`.
  _i5.Uint8List treasuryAccountKey() {
    final hashedKey = _treasuryAccount.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `treasuryPortion`.
  _i5.Uint8List treasuryPortionKey() {
    final hashedKey = _treasuryPortion.hashedKey();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Set the treasury account. Root only. Zero address is rejected (funds would be locked).
  ///
  /// **Important**: This only changes where *future* mining rewards are sent. Any balance
  /// that has already accumulated in the current treasury account is NOT automatically
  /// migrated to the new account. If you need to move existing funds, perform a separate
  /// balance transfer (e.g., via governance proposal) after updating the account.
  _i6.TreasuryPallet setTreasuryAccount({required _i2.AccountId32 account}) {
    return _i6.TreasuryPallet(_i7.SetTreasuryAccount(account: account));
  }

  /// Set the treasury portion (Permill, 0–100%). Root only.
  _i6.TreasuryPallet setTreasuryPortion({required _i3.Permill portion}) {
    return _i6.TreasuryPallet(_i7.SetTreasuryPortion(portion: portion));
  }
}
