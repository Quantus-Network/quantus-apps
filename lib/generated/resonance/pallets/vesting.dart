// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:typed_data' as _i5;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i3;

import '../types/pallet_vesting/pallet/call.dart' as _i8;
import '../types/pallet_vesting/pallet/vesting_schedule.dart' as _i2;
import '../types/resonance_runtime/runtime_call.dart' as _i6;
import '../types/sp_core/crypto/account_id32.dart' as _i7;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<BigInt, _i2.VestingSchedule> _vestingSchedules =
      const _i1.StorageMap<BigInt, _i2.VestingSchedule>(
    prefix: 'Vesting',
    storage: 'VestingSchedules',
    valueCodec: _i2.VestingSchedule.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i3.U64Codec.codec),
  );

  final _i1.StorageValue<BigInt> _scheduleCounter =
      const _i1.StorageValue<BigInt>(
    prefix: 'Vesting',
    storage: 'ScheduleCounter',
    valueCodec: _i3.U64Codec.codec,
  );

  _i4.Future<_i2.VestingSchedule?> vestingSchedules(
    BigInt key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _vestingSchedules.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _vestingSchedules.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  _i4.Future<BigInt> scheduleCounter({_i1.BlockHash? at}) async {
    final hashedKey = _scheduleCounter.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _scheduleCounter.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  /// Returns the storage key for `vestingSchedules`.
  _i5.Uint8List vestingSchedulesKey(BigInt key1) {
    final hashedKey = _vestingSchedules.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `scheduleCounter`.
  _i5.Uint8List scheduleCounterKey() {
    final hashedKey = _scheduleCounter.hashedKey();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `vestingSchedules`.
  _i5.Uint8List vestingSchedulesMapPrefix() {
    final hashedKey = _vestingSchedules.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  _i6.Vesting createVestingSchedule({
    required _i7.AccountId32 beneficiary,
    required BigInt amount,
    required BigInt start,
    required BigInt end,
  }) {
    return _i6.Vesting(_i8.CreateVestingSchedule(
      beneficiary: beneficiary,
      amount: amount,
      start: start,
      end: end,
    ));
  }

  _i6.Vesting claim({required BigInt scheduleId}) {
    return _i6.Vesting(_i8.Claim(scheduleId: scheduleId));
  }

  _i6.Vesting cancelVestingSchedule({required BigInt scheduleId}) {
    return _i6.Vesting(_i8.CancelVestingSchedule(scheduleId: scheduleId));
  }
}
