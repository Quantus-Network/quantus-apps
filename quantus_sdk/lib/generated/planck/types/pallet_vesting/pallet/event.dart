// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i3;

/// The `Event` enum of this pallet
abstract class Event {
  const Event();

  factory Event.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $EventCodec codec = $EventCodec();

  static const $Event values = $Event();

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

class $Event {
  const $Event();

  ScheduleCreated scheduleCreated({
    required BigInt scheduleId,
    required _i3.AccountId32 beneficiary,
    required BigInt start,
    required BigInt cliff,
    required BigInt end,
    required BigInt total,
  }) {
    return ScheduleCreated(
      scheduleId: scheduleId,
      beneficiary: beneficiary,
      start: start,
      cliff: cliff,
      end: end,
      total: total,
    );
  }

  Claimed claimed({required BigInt scheduleId, required _i3.AccountId32 beneficiary, required BigInt amount}) {
    return Claimed(scheduleId: scheduleId, beneficiary: beneficiary, amount: amount);
  }

  ScheduleEnded scheduleEnded({
    required BigInt scheduleId,
    required _i3.AccountId32 beneficiary,
    required BigInt vestedPaid,
    required BigInt unvestedReturned,
  }) {
    return ScheduleEnded(
      scheduleId: scheduleId,
      beneficiary: beneficiary,
      vestedPaid: vestedPaid,
      unvestedReturned: unvestedReturned,
    );
  }

  ScheduleRetargeted scheduleRetargeted({
    required BigInt scheduleId,
    required _i3.AccountId32 oldBeneficiary,
    required _i3.AccountId32 newBeneficiary,
  }) {
    return ScheduleRetargeted(scheduleId: scheduleId, oldBeneficiary: oldBeneficiary, newBeneficiary: newBeneficiary);
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return ScheduleCreated._decode(input);
      case 1:
        return Claimed._decode(input);
      case 2:
        return ScheduleEnded._decode(input);
      case 3:
        return ScheduleRetargeted._decode(input);
      default:
        throw Exception('Event: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Event value, _i1.Output output) {
    switch (value.runtimeType) {
      case ScheduleCreated:
        (value as ScheduleCreated).encodeTo(output);
        break;
      case Claimed:
        (value as Claimed).encodeTo(output);
        break;
      case ScheduleEnded:
        (value as ScheduleEnded).encodeTo(output);
        break;
      case ScheduleRetargeted:
        (value as ScheduleRetargeted).encodeTo(output);
        break;
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case ScheduleCreated:
        return (value as ScheduleCreated)._sizeHint();
      case Claimed:
        return (value as Claimed)._sizeHint();
      case ScheduleEnded:
        return (value as ScheduleEnded)._sizeHint();
      case ScheduleRetargeted:
        return (value as ScheduleRetargeted)._sizeHint();
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A new schedule was created and the pot funded from the treasury.
class ScheduleCreated extends Event {
  const ScheduleCreated({
    required this.scheduleId,
    required this.beneficiary,
    required this.start,
    required this.cliff,
    required this.end,
    required this.total,
  });

  factory ScheduleCreated._decode(_i1.Input input) {
    return ScheduleCreated(
      scheduleId: _i1.U64Codec.codec.decode(input),
      beneficiary: const _i1.U8ArrayCodec(32).decode(input),
      start: _i1.U64Codec.codec.decode(input),
      cliff: _i1.U64Codec.codec.decode(input),
      end: _i1.U64Codec.codec.decode(input),
      total: _i1.U128Codec.codec.decode(input),
    );
  }

  /// u64
  final BigInt scheduleId;

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
    'ScheduleCreated': {
      'scheduleId': scheduleId,
      'beneficiary': beneficiary.toList(),
      'start': start,
      'cliff': cliff,
      'end': end,
      'total': total,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(scheduleId);
    size = size + const _i3.AccountId32Codec().sizeHint(beneficiary);
    size = size + _i1.U64Codec.codec.sizeHint(start);
    size = size + _i1.U64Codec.codec.sizeHint(cliff);
    size = size + _i1.U64Codec.codec.sizeHint(end);
    size = size + _i1.U128Codec.codec.sizeHint(total);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    _i1.U64Codec.codec.encodeTo(scheduleId, output);
    const _i1.U8ArrayCodec(32).encodeTo(beneficiary, output);
    _i1.U64Codec.codec.encodeTo(start, output);
    _i1.U64Codec.codec.encodeTo(cliff, output);
    _i1.U64Codec.codec.encodeTo(end, output);
    _i1.U128Codec.codec.encodeTo(total, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleCreated &&
          other.scheduleId == scheduleId &&
          _i4.listsEqual(other.beneficiary, beneficiary) &&
          other.start == start &&
          other.cliff == cliff &&
          other.end == end &&
          other.total == total;

  @override
  int get hashCode => Object.hash(scheduleId, beneficiary, start, cliff, end, total);
}

/// Vested funds were paid out to the beneficiary.
class Claimed extends Event {
  const Claimed({required this.scheduleId, required this.beneficiary, required this.amount});

  factory Claimed._decode(_i1.Input input) {
    return Claimed(
      scheduleId: _i1.U64Codec.codec.decode(input),
      beneficiary: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// u64
  final BigInt scheduleId;

  /// T::AccountId
  final _i3.AccountId32 beneficiary;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'Claimed': {'scheduleId': scheduleId, 'beneficiary': beneficiary.toList(), 'amount': amount},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(scheduleId);
    size = size + const _i3.AccountId32Codec().sizeHint(beneficiary);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    _i1.U64Codec.codec.encodeTo(scheduleId, output);
    const _i1.U8ArrayCodec(32).encodeTo(beneficiary, output);
    _i1.U128Codec.codec.encodeTo(amount, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Claimed &&
          other.scheduleId == scheduleId &&
          _i4.listsEqual(other.beneficiary, beneficiary) &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(scheduleId, beneficiary, amount);
}

/// A schedule was ended early: unpaid vested part to the beneficiary,
/// unvested remainder back to the treasury.
class ScheduleEnded extends Event {
  const ScheduleEnded({
    required this.scheduleId,
    required this.beneficiary,
    required this.vestedPaid,
    required this.unvestedReturned,
  });

  factory ScheduleEnded._decode(_i1.Input input) {
    return ScheduleEnded(
      scheduleId: _i1.U64Codec.codec.decode(input),
      beneficiary: const _i1.U8ArrayCodec(32).decode(input),
      vestedPaid: _i1.U128Codec.codec.decode(input),
      unvestedReturned: _i1.U128Codec.codec.decode(input),
    );
  }

  /// u64
  final BigInt scheduleId;

  /// T::AccountId
  final _i3.AccountId32 beneficiary;

  /// BalanceOf<T>
  final BigInt vestedPaid;

  /// BalanceOf<T>
  final BigInt unvestedReturned;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'ScheduleEnded': {
      'scheduleId': scheduleId,
      'beneficiary': beneficiary.toList(),
      'vestedPaid': vestedPaid,
      'unvestedReturned': unvestedReturned,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(scheduleId);
    size = size + const _i3.AccountId32Codec().sizeHint(beneficiary);
    size = size + _i1.U128Codec.codec.sizeHint(vestedPaid);
    size = size + _i1.U128Codec.codec.sizeHint(unvestedReturned);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    _i1.U64Codec.codec.encodeTo(scheduleId, output);
    const _i1.U8ArrayCodec(32).encodeTo(beneficiary, output);
    _i1.U128Codec.codec.encodeTo(vestedPaid, output);
    _i1.U128Codec.codec.encodeTo(unvestedReturned, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleEnded &&
          other.scheduleId == scheduleId &&
          _i4.listsEqual(other.beneficiary, beneficiary) &&
          other.vestedPaid == vestedPaid &&
          other.unvestedReturned == unvestedReturned;

  @override
  int get hashCode => Object.hash(scheduleId, beneficiary, vestedPaid, unvestedReturned);
}

/// A schedule's beneficiary was changed. Nothing was paid out: the retarget
/// replaces the same grantee's wallet, so the accrued entitlement follows the
/// schedule to the new address.
class ScheduleRetargeted extends Event {
  const ScheduleRetargeted({required this.scheduleId, required this.oldBeneficiary, required this.newBeneficiary});

  factory ScheduleRetargeted._decode(_i1.Input input) {
    return ScheduleRetargeted(
      scheduleId: _i1.U64Codec.codec.decode(input),
      oldBeneficiary: const _i1.U8ArrayCodec(32).decode(input),
      newBeneficiary: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// u64
  final BigInt scheduleId;

  /// T::AccountId
  final _i3.AccountId32 oldBeneficiary;

  /// T::AccountId
  final _i3.AccountId32 newBeneficiary;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'ScheduleRetargeted': {
      'scheduleId': scheduleId,
      'oldBeneficiary': oldBeneficiary.toList(),
      'newBeneficiary': newBeneficiary.toList(),
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(scheduleId);
    size = size + const _i3.AccountId32Codec().sizeHint(oldBeneficiary);
    size = size + const _i3.AccountId32Codec().sizeHint(newBeneficiary);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(3, output);
    _i1.U64Codec.codec.encodeTo(scheduleId, output);
    const _i1.U8ArrayCodec(32).encodeTo(oldBeneficiary, output);
    const _i1.U8ArrayCodec(32).encodeTo(newBeneficiary, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleRetargeted &&
          other.scheduleId == scheduleId &&
          _i4.listsEqual(other.oldBeneficiary, oldBeneficiary) &&
          _i4.listsEqual(other.newBeneficiary, newBeneficiary);

  @override
  int get hashCode => Object.hash(scheduleId, oldBeneficiary, newBeneficiary);
}
