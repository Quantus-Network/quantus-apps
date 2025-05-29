// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i2;

class VestingSchedule {
  const VestingSchedule({
    required this.id,
    required this.creator,
    required this.beneficiary,
    required this.amount,
    required this.start,
    required this.end,
    required this.claimed,
  });

  factory VestingSchedule.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// u64
  final BigInt id;

  /// AccountId
  final _i2.AccountId32 creator;

  /// AccountId
  final _i2.AccountId32 beneficiary;

  /// Balance
  final BigInt amount;

  /// Moment
  final BigInt start;

  /// Moment
  final BigInt end;

  /// Balance
  final BigInt claimed;

  static const $VestingScheduleCodec codec = $VestingScheduleCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creator': creator.toList(),
        'beneficiary': beneficiary.toList(),
        'amount': amount,
        'start': start,
        'end': end,
        'claimed': claimed,
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is VestingSchedule &&
          other.id == id &&
          _i4.listsEqual(
            other.creator,
            creator,
          ) &&
          _i4.listsEqual(
            other.beneficiary,
            beneficiary,
          ) &&
          other.amount == amount &&
          other.start == start &&
          other.end == end &&
          other.claimed == claimed;

  @override
  int get hashCode => Object.hash(
        id,
        creator,
        beneficiary,
        amount,
        start,
        end,
        claimed,
      );
}

class $VestingScheduleCodec with _i1.Codec<VestingSchedule> {
  const $VestingScheduleCodec();

  @override
  void encodeTo(
    VestingSchedule obj,
    _i1.Output output,
  ) {
    _i1.U64Codec.codec.encodeTo(
      obj.id,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.creator,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.beneficiary,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      obj.amount,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      obj.start,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      obj.end,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      obj.claimed,
      output,
    );
  }

  @override
  VestingSchedule decode(_i1.Input input) {
    return VestingSchedule(
      id: _i1.U64Codec.codec.decode(input),
      creator: const _i1.U8ArrayCodec(32).decode(input),
      beneficiary: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
      start: _i1.U64Codec.codec.decode(input),
      end: _i1.U64Codec.codec.decode(input),
      claimed: _i1.U128Codec.codec.decode(input),
    );
  }

  @override
  int sizeHint(VestingSchedule obj) {
    int size = 0;
    size = size + _i1.U64Codec.codec.sizeHint(obj.id);
    size = size + const _i2.AccountId32Codec().sizeHint(obj.creator);
    size = size + const _i2.AccountId32Codec().sizeHint(obj.beneficiary);
    size = size + _i1.U128Codec.codec.sizeHint(obj.amount);
    size = size + _i1.U64Codec.codec.sizeHint(obj.start);
    size = size + _i1.U64Codec.codec.sizeHint(obj.end);
    size = size + _i1.U128Codec.codec.sizeHint(obj.claimed);
    return size;
  }
}
