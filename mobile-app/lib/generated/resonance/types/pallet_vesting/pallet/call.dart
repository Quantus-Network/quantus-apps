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

  CreateVestingSchedule createVestingSchedule({
    required _i3.AccountId32 beneficiary,
    required BigInt amount,
    required BigInt start,
    required BigInt end,
  }) {
    return CreateVestingSchedule(
      beneficiary: beneficiary,
      amount: amount,
      start: start,
      end: end,
    );
  }

  Claim claim({required BigInt scheduleId}) {
    return Claim(scheduleId: scheduleId);
  }

  CancelVestingSchedule cancelVestingSchedule({required BigInt scheduleId}) {
    return CancelVestingSchedule(scheduleId: scheduleId);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return CreateVestingSchedule._decode(input);
      case 1:
        return Claim._decode(input);
      case 2:
        return CancelVestingSchedule._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Call value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case CreateVestingSchedule:
        (value as CreateVestingSchedule).encodeTo(output);
        break;
      case Claim:
        (value as Claim).encodeTo(output);
        break;
      case CancelVestingSchedule:
        (value as CancelVestingSchedule).encodeTo(output);
        break;
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case CreateVestingSchedule:
        return (value as CreateVestingSchedule)._sizeHint();
      case Claim:
        return (value as Claim)._sizeHint();
      case CancelVestingSchedule:
        return (value as CancelVestingSchedule)._sizeHint();
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class CreateVestingSchedule extends Call {
  const CreateVestingSchedule({
    required this.beneficiary,
    required this.amount,
    required this.start,
    required this.end,
  });

  factory CreateVestingSchedule._decode(_i1.Input input) {
    return CreateVestingSchedule(
      beneficiary: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      start: _i1.U64Codec.codec.decode(input),
      end: _i1.U64Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 beneficiary;

  /// T::Balance
  final BigInt amount;

  /// T::Moment
  final BigInt start;

  /// T::Moment
  final BigInt end;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'create_vesting_schedule': {
          'beneficiary': beneficiary.toList(),
          'amount': amount,
          'start': start,
          'end': end,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(beneficiary);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    size = size + _i1.U64Codec.codec.sizeHint(start);
    size = size + _i1.U64Codec.codec.sizeHint(end);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      beneficiary,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      start,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      end,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CreateVestingSchedule &&
          _i4.listsEqual(
            other.beneficiary,
            beneficiary,
          ) &&
          other.amount == amount &&
          other.start == start &&
          other.end == end;

  @override
  int get hashCode => Object.hash(
        beneficiary,
        amount,
        start,
        end,
      );
}

class Claim extends Call {
  const Claim({required this.scheduleId});

  factory Claim._decode(_i1.Input input) {
    return Claim(scheduleId: _i1.U64Codec.codec.decode(input));
  }

  /// u64
  final BigInt scheduleId;

  @override
  Map<String, Map<String, BigInt>> toJson() => {
        'claim': {'scheduleId': scheduleId}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(scheduleId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      scheduleId,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Claim && other.scheduleId == scheduleId;

  @override
  int get hashCode => scheduleId.hashCode;
}

class CancelVestingSchedule extends Call {
  const CancelVestingSchedule({required this.scheduleId});

  factory CancelVestingSchedule._decode(_i1.Input input) {
    return CancelVestingSchedule(scheduleId: _i1.U64Codec.codec.decode(input));
  }

  /// u64
  final BigInt scheduleId;

  @override
  Map<String, Map<String, BigInt>> toJson() => {
        'cancel_vesting_schedule': {'scheduleId': scheduleId}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(scheduleId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      scheduleId,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CancelVestingSchedule && other.scheduleId == scheduleId;

  @override
  int get hashCode => scheduleId.hashCode;
}
