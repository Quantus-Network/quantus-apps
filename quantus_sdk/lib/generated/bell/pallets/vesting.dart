// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i6;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/frame_support/pallet_id.dart' as _i10;
import '../types/pallet_vesting/pallet/call.dart' as _i8;
import '../types/pallet_vesting/pallet/launch_anchor.dart' as _i4;
import '../types/pallet_vesting/pallet/vesting_schedule.dart' as _i3;
import '../types/quantus_runtime/runtime_call.dart' as _i7;
import '../types/sp_core/crypto/account_id32.dart' as _i9;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<BigInt> _nextScheduleId = const _i1.StorageValue<BigInt>(
    prefix: 'Vesting',
    storage: 'NextScheduleId',
    valueCodec: _i2.U64Codec.codec,
  );

  final _i1.StorageMap<BigInt, _i3.VestingSchedule> _schedules = const _i1.StorageMap<BigInt, _i3.VestingSchedule>(
    prefix: 'Vesting',
    storage: 'Schedules',
    valueCodec: _i3.VestingSchedule.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U64Codec.codec),
  );

  final _i1.StorageValue<_i4.LaunchAnchor> _launch = const _i1.StorageValue<_i4.LaunchAnchor>(
    prefix: 'Vesting',
    storage: 'Launch',
    valueCodec: _i4.LaunchAnchor.codec,
  );

  /// Next schedule id to assign. Ids are sequential and never reused.
  _i5.Future<BigInt> nextScheduleId({_i1.BlockHash? at}) async {
    final hashedKey = _nextScheduleId.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _nextScheduleId.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  /// All vesting schedules by id. A beneficiary may appear in any number of entries.
  _i5.Future<_i3.VestingSchedule?> schedules(BigInt key1, {_i1.BlockHash? at}) async {
    final hashedKey = _schedules.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _schedules.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  _i5.Future<_i4.LaunchAnchor?> launch({_i1.BlockHash? at}) async {
    final hashedKey = _launch.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _launch.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// All vesting schedules by id. A beneficiary may appear in any number of entries.
  _i5.Future<List<_i3.VestingSchedule?>> multiSchedules(List<BigInt> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _schedules.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _schedules.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `nextScheduleId`.
  _i6.Uint8List nextScheduleIdKey() {
    final hashedKey = _nextScheduleId.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `schedules`.
  _i6.Uint8List schedulesKey(BigInt key1) {
    final hashedKey = _schedules.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `launch`.
  _i6.Uint8List launchKey() {
    final hashedKey = _launch.hashedKey();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `schedules`.
  _i6.Uint8List schedulesMapPrefix() {
    final hashedKey = _schedules.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Pay the largest valid claim on `schedule_id` to its beneficiary. Non-final
  /// payouts are rounded down to [`NON_FINAL_PAYOUT_QUANTA`] leaf quanta; the
  /// leftover stays on the schedule until a later claim or the exact final
  /// payout (at least one [`Config::PayoutQuantum`]).
  ///
  /// Permissionless: any signed account may call this for any schedule; the payout
  /// always goes to the stored beneficiary. This is the only claim path for
  /// beneficiaries that cannot sign (wormhole addresses, high-security accounts).
  _i7.Vesting claim({required BigInt scheduleId}) {
    return _i7.Vesting(_i8.Claim(scheduleId: scheduleId));
  }

  /// Create a new schedule under the next free id, moving `total` from the
  /// treasury account into the pot in the same call (recorded as a leaf).
  _i7.Vesting createSchedule({
    required _i9.AccountId32 beneficiary,
    required BigInt start,
    required BigInt cliff,
    required BigInt end,
    required BigInt total,
  }) {
    return _i7.Vesting(
      _i8.CreateSchedule(beneficiary: beneficiary, start: start, cliff: cliff, end: end, total: total),
    );
  }

  /// End a schedule early: the still-unpaid vested part (rounded to the nearest
  /// [`Config::PayoutQuantum`]) goes to the beneficiary if it is at least one
  /// quantum; otherwise that sliver is refunded with the unvested remainder.
  /// Both legs are recorded as wormhole leaves.
  _i7.Vesting endSchedule({required BigInt scheduleId}) {
    return _i7.Vesting(_i8.EndSchedule(scheduleId: scheduleId));
  }

  /// Change the schedule's beneficiary without paying anything out. A retarget
  /// replaces the wallet of the *same* grantee (lost-key remedy): the old address
  /// may be lost or stolen, so settling it would burn funds or pay the thief.
  /// Everything vested but unclaimed stays on the schedule and goes to the new
  /// wallet at its next claim. (A permissionless claim landing before the
  /// retarget still pays the old address, so rotate promptly.)
  _i7.Vesting retargetSchedule({required BigInt scheduleId, required _i9.AccountId32 newBeneficiary}) {
    return _i7.Vesting(_i8.RetargetSchedule(scheduleId: scheduleId, newBeneficiary: newBeneficiary));
  }
}

class Constants {
  Constants();

  /// Derives the pot's sovereign account.
  final _i10.PalletId palletId = const <int>[113, 118, 101, 115, 116, 105, 110, 103];

  /// Wormhole leaf amount quantum. ZK-tree leaves commit `amount / quantum`, so a
  /// payout below one quantum would create a zero-value leaf: funds moved to a
  /// keyless beneficiary would be irrecoverable. Every schedule total must be a
  /// positive multiple of this. Intermediate claims round down further to
  /// [`NON_FINAL_PAYOUT_QUANTA`] leaf quanta; the final claim may be a single
  /// quantum.
  final BigInt payoutQuantum = BigInt.from(10000000000);

  /// Minimum elapsed milliseconds between successful claims on one schedule.
  final BigInt minClaimInterval = BigInt.from(86400000);
}
