// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../../quantus_runtime/runtime_hold_reason.dart' as _i4;
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

  Held held({
    required _i3.AccountId32 who,
    required int assetId,
    required _i4.RuntimeHoldReason reason,
    required BigInt amount,
  }) {
    return Held(
      who: who,
      assetId: assetId,
      reason: reason,
      amount: amount,
    );
  }

  Released released({
    required _i3.AccountId32 who,
    required int assetId,
    required _i4.RuntimeHoldReason reason,
    required BigInt amount,
  }) {
    return Released(
      who: who,
      assetId: assetId,
      reason: reason,
      amount: amount,
    );
  }

  Burned burned({
    required _i3.AccountId32 who,
    required int assetId,
    required _i4.RuntimeHoldReason reason,
    required BigInt amount,
  }) {
    return Burned(
      who: who,
      assetId: assetId,
      reason: reason,
      amount: amount,
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
        return Held._decode(input);
      case 1:
        return Released._decode(input);
      case 2:
        return Burned._decode(input);
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
      case Held:
        (value as Held).encodeTo(output);
        break;
      case Released:
        (value as Released).encodeTo(output);
        break;
      case Burned:
        (value as Burned).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case Held:
        return (value as Held)._sizeHint();
      case Released:
        return (value as Released)._sizeHint();
      case Burned:
        return (value as Burned)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// `who`s balance on hold was increased by `amount`.
class Held extends Event {
  const Held({
    required this.who,
    required this.assetId,
    required this.reason,
    required this.amount,
  });

  factory Held._decode(_i1.Input input) {
    return Held(
      who: const _i1.U8ArrayCodec(32).decode(input),
      assetId: _i1.U32Codec.codec.decode(input),
      reason: _i4.RuntimeHoldReason.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// T::AssetId
  final int assetId;

  /// T::RuntimeHoldReason
  final _i4.RuntimeHoldReason reason;

  /// T::Balance
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Held': {
          'who': who.toList(),
          'assetId': assetId,
          'reason': reason.toJson(),
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + _i1.U32Codec.codec.sizeHint(assetId);
    size = size + _i4.RuntimeHoldReason.codec.sizeHint(reason);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      who,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      assetId,
      output,
    );
    _i4.RuntimeHoldReason.codec.encodeTo(
      reason,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Held &&
          _i5.listsEqual(
            other.who,
            who,
          ) &&
          other.assetId == assetId &&
          other.reason == reason &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        who,
        assetId,
        reason,
        amount,
      );
}

/// `who`s balance on hold was decreased by `amount`.
class Released extends Event {
  const Released({
    required this.who,
    required this.assetId,
    required this.reason,
    required this.amount,
  });

  factory Released._decode(_i1.Input input) {
    return Released(
      who: const _i1.U8ArrayCodec(32).decode(input),
      assetId: _i1.U32Codec.codec.decode(input),
      reason: _i4.RuntimeHoldReason.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// T::AssetId
  final int assetId;

  /// T::RuntimeHoldReason
  final _i4.RuntimeHoldReason reason;

  /// T::Balance
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Released': {
          'who': who.toList(),
          'assetId': assetId,
          'reason': reason.toJson(),
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + _i1.U32Codec.codec.sizeHint(assetId);
    size = size + _i4.RuntimeHoldReason.codec.sizeHint(reason);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      who,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      assetId,
      output,
    );
    _i4.RuntimeHoldReason.codec.encodeTo(
      reason,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Released &&
          _i5.listsEqual(
            other.who,
            who,
          ) &&
          other.assetId == assetId &&
          other.reason == reason &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        who,
        assetId,
        reason,
        amount,
      );
}

/// `who`s balance on hold was burned by `amount`.
class Burned extends Event {
  const Burned({
    required this.who,
    required this.assetId,
    required this.reason,
    required this.amount,
  });

  factory Burned._decode(_i1.Input input) {
    return Burned(
      who: const _i1.U8ArrayCodec(32).decode(input),
      assetId: _i1.U32Codec.codec.decode(input),
      reason: _i4.RuntimeHoldReason.codec.decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 who;

  /// T::AssetId
  final int assetId;

  /// T::RuntimeHoldReason
  final _i4.RuntimeHoldReason reason;

  /// T::Balance
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Burned': {
          'who': who.toList(),
          'assetId': assetId,
          'reason': reason.toJson(),
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(who);
    size = size + _i1.U32Codec.codec.sizeHint(assetId);
    size = size + _i4.RuntimeHoldReason.codec.sizeHint(reason);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      who,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      assetId,
      output,
    );
    _i4.RuntimeHoldReason.codec.encodeTo(
      reason,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Burned &&
          _i5.listsEqual(
            other.who,
            who,
          ) &&
          other.assetId == assetId &&
          other.reason == reason &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        who,
        assetId,
        reason,
        amount,
      );
}
