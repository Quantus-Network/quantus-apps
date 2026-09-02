// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i3;

/// Contains a variant per dispatchable extrinsic that this pallet has.
abstract class Call {
  const Call();

  factory Call.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $CallCodec codec = $CallCodec();

  static const $Call values = $Call();

  _i2.Uint8List encode() {
    final output = _i1.ByteOutput(codec.sizeHint(this));
    codec.encodeTo(this, output);
    return output.toBytes();
  }

  int sizeHint() {
    return codec.sizeHint(this);
  }

  Map<String, Map<String, dynamic>> toJson();
}

class $Call {
  const $Call();

  Claim claim({required BigInt scheduleId}) {
    return Claim(scheduleId: scheduleId);
  }

  CreateSchedule createSchedule({
    required _i3.AccountId32 beneficiary,
    required BigInt start,
    required BigInt cliff,
    required BigInt end,
    required BigInt total,
  }) {
    return CreateSchedule(beneficiary: beneficiary, start: start, cliff: cliff, end: end, total: total);
  }

  EndSchedule endSchedule({required BigInt scheduleId}) {
    return EndSchedule(scheduleId: scheduleId);
  }

  RetargetSchedule retargetSchedule({required BigInt scheduleId, required _i3.AccountId32 newBeneficiary}) {
    return RetargetSchedule(scheduleId: scheduleId, newBeneficiary: newBeneficiary);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Claim._decode(input);
      case 1:
        return CreateSchedule._decode(input);
      case 2:
        return EndSchedule._decode(input);
      case 3:
        return RetargetSchedule._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Call value, _i1.Output output) {
    switch (value.runtimeType) {
      case Claim:
        (value as Claim).encodeTo(output);
        break;
      case CreateSchedule:
        (value as CreateSchedule).encodeTo(output);
        break;
      case EndSchedule:
        (value as EndSchedule).encodeTo(output);
        break;
      case RetargetSchedule:
        (value as RetargetSchedule).encodeTo(output);
        break;
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case Claim:
        return (value as Claim)._sizeHint();
      case CreateSchedule:
        return (value as CreateSchedule)._sizeHint();
      case EndSchedule:
        return (value as EndSchedule)._sizeHint();
      case RetargetSchedule:
        return (value as RetargetSchedule)._sizeHint();
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Pay the largest valid claim on `schedule_id` to its beneficiary. Payouts are
/// rounded down to [`Config::PayoutQuantum`], must meet [`Config::MinimumPayout`],
/// and reserve at least one minimum-sized final claim unless the schedule is fully
/// vested. Non-final payouts are further rounded down to
/// [`NON_FINAL_PAYOUT_QUANTA`] leaf quanta; the leftover stays on the schedule
/// until a later claim or the exact final payout.
///
/// Permissionless: any signed account may call this for any schedule; the payout
/// always goes to the stored beneficiary. This is the only claim path for
/// beneficiaries that cannot sign (wormhole addresses, high-security accounts).
class Claim extends Call {
  const Claim({required this.scheduleId});

  factory Claim._decode(_i1.Input input) {
    return Claim(scheduleId: _i1.U64Codec.codec.decode(input));
  }

  /// u64
  final BigInt scheduleId;

  @override
  Map<String, Map<String, BigInt>> toJson() => {
    'claim': {'scheduleId': scheduleId},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(scheduleId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    _i1.U64Codec.codec.encodeTo(scheduleId, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Claim && other.scheduleId == scheduleId;

  @override
  int get hashCode => scheduleId.hashCode;
}

/// Create a new schedule under the next free id, moving `total` from the
/// treasury account into the pot in the same call.
class CreateSchedule extends Call {
  const CreateSchedule({
    required this.beneficiary,
    required this.start,
    required this.cliff,
    required this.end,
    required this.total,
  });

  factory CreateSchedule._decode(_i1.Input input) {
    return CreateSchedule(
      beneficiary: const _i1.U8ArrayCodec(32).decode(input),
      start: _i1.U64Codec.codec.decode(input),
      cliff: _i1.U64Codec.codec.decode(input),
      end: _i1.U64Codec.codec.decode(input),
      total: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 beneficiary;

  /// Moment
  final BigInt start;

  /// Moment
  final BigInt cliff;

  /// Moment
  final BigInt end;

  /// BalanceOf<T>
  final BigInt total;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'create_schedule': {
      'beneficiary': beneficiary.toList(),
      'start': start,
      'cliff': cliff,
      'end': end,
      'total': total,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(beneficiary);
    size = size + _i1.U64Codec.codec.sizeHint(start);
    size = size + _i1.U64Codec.codec.sizeHint(cliff);
    size = size + _i1.U64Codec.codec.sizeHint(end);
    size = size + _i1.U128Codec.codec.sizeHint(total);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    const _i1.U8ArrayCodec(32).encodeTo(beneficiary, output);
    _i1.U64Codec.codec.encodeTo(start, output);
    _i1.U64Codec.codec.encodeTo(cliff, output);
    _i1.U64Codec.codec.encodeTo(end, output);
    _i1.U128Codec.codec.encodeTo(total, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateSchedule &&
          _i4.listsEqual(other.beneficiary, beneficiary) &&
          other.start == start &&
          other.cliff == cliff &&
          other.end == end &&
          other.total == total;

  @override
  int get hashCode => Object.hash(beneficiary, start, cliff, end, total);
}

/// End a schedule early: the still-unpaid vested part (rounded to the nearest
/// [`Config::PayoutQuantum`]) goes to the beneficiary if it meets
/// [`Config::MinimumPayout`]; otherwise that sliver is refunded with the
/// unvested remainder. The treasury is signature-controlled and needs no
/// wormhole leaf, so the refund is not quantized and never blocks ending.
class EndSchedule extends Call {
  const EndSchedule({required this.scheduleId});

  factory EndSchedule._decode(_i1.Input input) {
    return EndSchedule(scheduleId: _i1.U64Codec.codec.decode(input));
  }

  /// u64
  final BigInt scheduleId;

  @override
  Map<String, Map<String, BigInt>> toJson() => {
    'end_schedule': {'scheduleId': scheduleId},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(scheduleId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    _i1.U64Codec.codec.encodeTo(scheduleId, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is EndSchedule && other.scheduleId == scheduleId;

  @override
  int get hashCode => scheduleId.hashCode;
}

/// Change the schedule's beneficiary without paying anything out. A retarget
/// replaces the wallet of the *same* grantee (lost-key remedy): the old address
/// may be lost or stolen, so settling it would burn funds or pay the thief.
/// Everything vested but unclaimed stays on the schedule and goes to the new
/// wallet at its next claim. (A permissionless claim landing before the
/// retarget still pays the old address, so rotate promptly.)
class RetargetSchedule extends Call {
  const RetargetSchedule({required this.scheduleId, required this.newBeneficiary});

  factory RetargetSchedule._decode(_i1.Input input) {
    return RetargetSchedule(
      scheduleId: _i1.U64Codec.codec.decode(input),
      newBeneficiary: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// u64
  final BigInt scheduleId;

  /// T::AccountId
  final _i3.AccountId32 newBeneficiary;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'retarget_schedule': {'scheduleId': scheduleId, 'newBeneficiary': newBeneficiary.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(scheduleId);
    size = size + const _i3.AccountId32Codec().sizeHint(newBeneficiary);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(3, output);
    _i1.U64Codec.codec.encodeTo(scheduleId, output);
    const _i1.U8ArrayCodec(32).encodeTo(newBeneficiary, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetargetSchedule &&
          other.scheduleId == scheduleId &&
          _i4.listsEqual(other.newBeneficiary, newBeneficiary);

  @override
  int get hashCode => Object.hash(scheduleId, newBeneficiary);
}
