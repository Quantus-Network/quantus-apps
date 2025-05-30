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

  Delegated delegated({
    required _i3.AccountId32 agent,
    required _i3.AccountId32 delegator,
    required BigInt amount,
  }) {
    return Delegated(
      agent: agent,
      delegator: delegator,
      amount: amount,
    );
  }

  Released released({
    required _i3.AccountId32 agent,
    required _i3.AccountId32 delegator,
    required BigInt amount,
  }) {
    return Released(
      agent: agent,
      delegator: delegator,
      amount: amount,
    );
  }

  Slashed slashed({
    required _i3.AccountId32 agent,
    required _i3.AccountId32 delegator,
    required BigInt amount,
  }) {
    return Slashed(
      agent: agent,
      delegator: delegator,
      amount: amount,
    );
  }

  MigratedDelegation migratedDelegation({
    required _i3.AccountId32 agent,
    required _i3.AccountId32 delegator,
    required BigInt amount,
  }) {
    return MigratedDelegation(
      agent: agent,
      delegator: delegator,
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
        return Delegated._decode(input);
      case 1:
        return Released._decode(input);
      case 2:
        return Slashed._decode(input);
      case 3:
        return MigratedDelegation._decode(input);
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
      case Delegated:
        (value as Delegated).encodeTo(output);
        break;
      case Released:
        (value as Released).encodeTo(output);
        break;
      case Slashed:
        (value as Slashed).encodeTo(output);
        break;
      case MigratedDelegation:
        (value as MigratedDelegation).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case Delegated:
        return (value as Delegated)._sizeHint();
      case Released:
        return (value as Released)._sizeHint();
      case Slashed:
        return (value as Slashed)._sizeHint();
      case MigratedDelegation:
        return (value as MigratedDelegation)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Funds delegated by a delegator.
class Delegated extends Event {
  const Delegated({
    required this.agent,
    required this.delegator,
    required this.amount,
  });

  factory Delegated._decode(_i1.Input input) {
    return Delegated(
      agent: const _i1.U8ArrayCodec(32).decode(input),
      delegator: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 agent;

  /// T::AccountId
  final _i3.AccountId32 delegator;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Delegated': {
          'agent': agent.toList(),
          'delegator': delegator.toList(),
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(agent);
    size = size + const _i3.AccountId32Codec().sizeHint(delegator);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      agent,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      delegator,
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
      other is Delegated &&
          _i4.listsEqual(
            other.agent,
            agent,
          ) &&
          _i4.listsEqual(
            other.delegator,
            delegator,
          ) &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        agent,
        delegator,
        amount,
      );
}

/// Funds released to a delegator.
class Released extends Event {
  const Released({
    required this.agent,
    required this.delegator,
    required this.amount,
  });

  factory Released._decode(_i1.Input input) {
    return Released(
      agent: const _i1.U8ArrayCodec(32).decode(input),
      delegator: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 agent;

  /// T::AccountId
  final _i3.AccountId32 delegator;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Released': {
          'agent': agent.toList(),
          'delegator': delegator.toList(),
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(agent);
    size = size + const _i3.AccountId32Codec().sizeHint(delegator);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      agent,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      delegator,
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
          _i4.listsEqual(
            other.agent,
            agent,
          ) &&
          _i4.listsEqual(
            other.delegator,
            delegator,
          ) &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        agent,
        delegator,
        amount,
      );
}

/// Funds slashed from a delegator.
class Slashed extends Event {
  const Slashed({
    required this.agent,
    required this.delegator,
    required this.amount,
  });

  factory Slashed._decode(_i1.Input input) {
    return Slashed(
      agent: const _i1.U8ArrayCodec(32).decode(input),
      delegator: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 agent;

  /// T::AccountId
  final _i3.AccountId32 delegator;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'Slashed': {
          'agent': agent.toList(),
          'delegator': delegator.toList(),
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(agent);
    size = size + const _i3.AccountId32Codec().sizeHint(delegator);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      agent,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      delegator,
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
      other is Slashed &&
          _i4.listsEqual(
            other.agent,
            agent,
          ) &&
          _i4.listsEqual(
            other.delegator,
            delegator,
          ) &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        agent,
        delegator,
        amount,
      );
}

/// Unclaimed delegation funds migrated to delegator.
class MigratedDelegation extends Event {
  const MigratedDelegation({
    required this.agent,
    required this.delegator,
    required this.amount,
  });

  factory MigratedDelegation._decode(_i1.Input input) {
    return MigratedDelegation(
      agent: const _i1.U8ArrayCodec(32).decode(input),
      delegator: const _i1.U8ArrayCodec(32).decode(input),
      amount: _i1.U128Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 agent;

  /// T::AccountId
  final _i3.AccountId32 delegator;

  /// BalanceOf<T>
  final BigInt amount;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'MigratedDelegation': {
          'agent': agent.toList(),
          'delegator': delegator.toList(),
          'amount': amount,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(agent);
    size = size + const _i3.AccountId32Codec().sizeHint(delegator);
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      agent,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      delegator,
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
      other is MigratedDelegation &&
          _i4.listsEqual(
            other.agent,
            agent,
          ) &&
          _i4.listsEqual(
            other.delegator,
            delegator,
          ) &&
          other.amount == amount;

  @override
  int get hashCode => Object.hash(
        agent,
        delegator,
        amount,
      );
}
