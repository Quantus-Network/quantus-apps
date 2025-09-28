// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i3;
import 'dart:typed_data' as _i4;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/frame_support/pallet_id.dart' as _i5;
import '../types/sp_core/crypto/account_id32.dart' as _i6;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<BigInt> _collectedFees =
      const _i1.StorageValue<BigInt>(
    prefix: 'MiningRewards',
    storage: 'CollectedFees',
    valueCodec: _i2.U128Codec.codec,
  );

  _i3.Future<BigInt> collectedFees({_i1.BlockHash? at}) async {
    final hashedKey = _collectedFees.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _collectedFees.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  /// Returns the storage key for `collectedFees`.
  _i4.Uint8List collectedFeesKey() {
    final hashedKey = _collectedFees.hashedKey();
    return hashedKey;
  }
}

class Constants {
  Constants();

  /// The base block reward given to miners
  final BigInt minerBlockReward = BigInt.from(10000000000000);

  /// The base block reward given to treasury
  final BigInt treasuryBlockReward = BigInt.from(1000000000000);

  /// The treasury pallet ID
  final _i5.PalletId treasuryPalletId = const <int>[
    112,
    121,
    47,
    116,
    114,
    115,
    114,
    121,
  ];

  /// Account ID used as the "from" account when creating transfer proofs for minted tokens
  final _i6.AccountId32 mintingAccount = const <int>[
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
}
