// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;
import 'dart:typed_data' as _i4;

import 'package:polkadart/polkadart.dart' as _i1;

import '../types/pallet_treasury/pallet/call.dart' as _i6;
import '../types/quantus_runtime/runtime_call.dart' as _i5;
import '../types/sp_core/crypto/account_id32.dart' as _i2;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<_i2.AccountId32> _treasuryAccount = const _i1.StorageValue<_i2.AccountId32>(
    prefix: 'TreasuryPallet',
    storage: 'TreasuryAccount',
    valueCodec: _i2.AccountId32Codec(),
  );

  /// The treasury account that holds treasury funds.
  _i3.Future<_i2.AccountId32?> treasuryAccount({_i1.BlockHash? at}) async {
    final hashedKey = _treasuryAccount.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _treasuryAccount.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Returns the storage key for `treasuryAccount`.
  _i4.Uint8List treasuryAccountKey() {
    final hashedKey = _treasuryAccount.hashedKey();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Set the treasury account. Root only. Zero address is rejected (funds would be locked).
  ///
  /// **Important**: This only changes where *future* treasury credits are sent. Any balance
  /// that has already accumulated in the current treasury account is NOT automatically
  /// migrated to the new account. If you need to move existing funds, perform a separate
  /// balance transfer (e.g., via governance proposal) after updating the account.
  _i5.TreasuryPallet setTreasuryAccount({required _i2.AccountId32 account}) {
    return _i5.TreasuryPallet(_i6.SetTreasuryAccount(account: account));
  }
}
