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

  Map<String, List<dynamic>> toJson();
}

class $Event {
  const $Event();

  VestingScheduleCreated vestingScheduleCreated(
    _i3.AccountId32 value0,
    BigInt value1,
    BigInt value2,
    BigInt value3,
    BigInt value4,
  ) {
    return VestingScheduleCreated(
      value0,
      value1,
      value2,
      value3,
      value4,
    );
  }

  TokensClaimed tokensClaimed(
    _i3.AccountId32 value0,
    BigInt value1,
    BigInt value2,
  ) {
    return TokensClaimed(
      value0,
      value1,
      value2,
    );
  }

  VestingScheduleCancelled vestingScheduleCancelled(
    _i3.AccountId32 value0,
    BigInt value1,
  ) {
    return VestingScheduleCancelled(
      value0,
      value1,
    );
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return VestingScheduleCreated._decode(input);
      case 1:
        return TokensClaimed._decode(input);
      case 2:
        return VestingScheduleCancelled._decode(input);
      default:
        throw Exception('Event: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Event value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case VestingScheduleCreated:
        (value as VestingScheduleCreated).encodeTo(output);
        break;
      case TokensClaimed:
        (value as TokensClaimed).encodeTo(output);
        break;
      case VestingScheduleCancelled:
        (value as VestingScheduleCancelled).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case VestingScheduleCreated:
        return (value as VestingScheduleCreated)._sizeHint();
      case TokensClaimed:
        return (value as TokensClaimed)._sizeHint();
      case VestingScheduleCancelled:
        return (value as VestingScheduleCancelled)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class VestingScheduleCreated extends Event {
  const VestingScheduleCreated(
    this.value0,
    this.value1,
    this.value2,
    this.value3,
    this.value4,
  );

  factory VestingScheduleCreated._decode(_i1.Input input) {
    return VestingScheduleCreated(
      const _i1.U8ArrayCodec(32).decode(input),
      _i1.U128Codec.codec.decode(input),
      _i1.U64Codec.codec.decode(input),
      _i1.U64Codec.codec.decode(input),
      _i1.U64Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 value0;

  /// T::Balance
  final BigInt value1;

  /// T::Moment
  final BigInt value2;

  /// T::Moment
  final BigInt value3;

  /// u64
  final BigInt value4;

  @override
  Map<String, List<dynamic>> toJson() => {
        'VestingScheduleCreated': [
          value0.toList(),
          value1,
          value2,
          value3,
          value4,
        ]
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(value0);
    size = size + _i1.U128Codec.codec.sizeHint(value1);
    size = size + _i1.U64Codec.codec.sizeHint(value2);
    size = size + _i1.U64Codec.codec.sizeHint(value3);
    size = size + _i1.U64Codec.codec.sizeHint(value4);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      value0,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      value1,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      value2,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      value3,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      value4,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is VestingScheduleCreated &&
          _i4.listsEqual(
            other.value0,
            value0,
          ) &&
          other.value1 == value1 &&
          other.value2 == value2 &&
          other.value3 == value3 &&
          other.value4 == value4;

  @override
  int get hashCode => Object.hash(
        value0,
        value1,
        value2,
        value3,
        value4,
      );
}

class TokensClaimed extends Event {
  const TokensClaimed(
    this.value0,
    this.value1,
    this.value2,
  );

  factory TokensClaimed._decode(_i1.Input input) {
    return TokensClaimed(
      const _i1.U8ArrayCodec(32).decode(input),
      _i1.U128Codec.codec.decode(input),
      _i1.U64Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 value0;

  /// T::Balance
  final BigInt value1;

  /// u64
  final BigInt value2;

  @override
  Map<String, List<dynamic>> toJson() => {
        'TokensClaimed': [
          value0.toList(),
          value1,
          value2,
        ]
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(value0);
    size = size + _i1.U128Codec.codec.sizeHint(value1);
    size = size + _i1.U64Codec.codec.sizeHint(value2);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      value0,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      value1,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      value2,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is TokensClaimed &&
          _i4.listsEqual(
            other.value0,
            value0,
          ) &&
          other.value1 == value1 &&
          other.value2 == value2;

  @override
  int get hashCode => Object.hash(
        value0,
        value1,
        value2,
      );
}

class VestingScheduleCancelled extends Event {
  const VestingScheduleCancelled(
    this.value0,
    this.value1,
  );

  factory VestingScheduleCancelled._decode(_i1.Input input) {
    return VestingScheduleCancelled(
      const _i1.U8ArrayCodec(32).decode(input),
      _i1.U64Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 value0;

  /// u64
  final BigInt value1;

  @override
  Map<String, List<dynamic>> toJson() => {
        'VestingScheduleCancelled': [
          value0.toList(),
          value1,
        ]
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(value0);
    size = size + _i1.U64Codec.codec.sizeHint(value1);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      value0,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      value1,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is VestingScheduleCancelled &&
          _i4.listsEqual(
            other.value0,
            value0,
          ) &&
          other.value1 == value1;

  @override
  int get hashCode => Object.hash(
        value0,
        value1,
      );
}
