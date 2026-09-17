// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i2;

class VestingSchedule {
  const VestingSchedule({
    required this.beneficiary,
    required this.start,
    required this.cliff,
    required this.end,
    required this.total,
    required this.claimed,
    this.lastClaimAt,
  });

  factory VestingSchedule.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// AccountId
  final _i2.AccountId32 beneficiary;

  /// Moment
  final BigInt start;

  /// Moment
  final BigInt cliff;

  /// Moment
  final BigInt end;

  /// Balance
  final BigInt total;

  /// Balance
  final BigInt claimed;

  /// Option<Moment>
  final BigInt? lastClaimAt;

  static const $VestingScheduleCodec codec = $VestingScheduleCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
    'beneficiary': beneficiary.toList(),
    'start': start,
    'cliff': cliff,
    'end': end,
    'total': total,
    'claimed': claimed,
    'lastClaimAt': lastClaimAt,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VestingSchedule &&
          _i4.listsEqual(other.beneficiary, beneficiary) &&
          other.start == start &&
          other.cliff == cliff &&
          other.end == end &&
          other.total == total &&
          other.claimed == claimed &&
          other.lastClaimAt == lastClaimAt;

  @override
  int get hashCode => Object.hash(beneficiary, start, cliff, end, total, claimed, lastClaimAt);
}

class $VestingScheduleCodec with _i1.Codec<VestingSchedule> {
  const $VestingScheduleCodec();

  @override
  void encodeTo(VestingSchedule obj, _i1.Output output) {
    const _i1.U8ArrayCodec(32).encodeTo(obj.beneficiary, output);
    _i1.U64Codec.codec.encodeTo(obj.start, output);
    _i1.U64Codec.codec.encodeTo(obj.cliff, output);
    _i1.U64Codec.codec.encodeTo(obj.end, output);
    _i1.U128Codec.codec.encodeTo(obj.total, output);
    _i1.U128Codec.codec.encodeTo(obj.claimed, output);
    const _i1.OptionCodec<BigInt>(_i1.U64Codec.codec).encodeTo(obj.lastClaimAt, output);
  }

  @override
  VestingSchedule decode(_i1.Input input) {
    return VestingSchedule(
      beneficiary: const _i1.U8ArrayCodec(32).decode(input),
      start: _i1.U64Codec.codec.decode(input),
      cliff: _i1.U64Codec.codec.decode(input),
      end: _i1.U64Codec.codec.decode(input),
      total: _i1.U128Codec.codec.decode(input),
      claimed: _i1.U128Codec.codec.decode(input),
      lastClaimAt: const _i1.OptionCodec<BigInt>(_i1.U64Codec.codec).decode(input),
    );
  }

  @override
  int sizeHint(VestingSchedule obj) {
    int size = 0;
    size = size + const _i2.AccountId32Codec().sizeHint(obj.beneficiary);
    size = size + _i1.U64Codec.codec.sizeHint(obj.start);
    size = size + _i1.U64Codec.codec.sizeHint(obj.cliff);
    size = size + _i1.U64Codec.codec.sizeHint(obj.end);
    size = size + _i1.U128Codec.codec.sizeHint(obj.total);
    size = size + _i1.U128Codec.codec.sizeHint(obj.claimed);
    size = size + const _i1.OptionCodec<BigInt>(_i1.U64Codec.codec).sizeHint(obj.lastClaimAt);
    return size;
  }
}
