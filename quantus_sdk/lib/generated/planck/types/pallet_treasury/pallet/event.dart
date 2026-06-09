// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../../sp_arithmetic/per_things/permill.dart' as _i4;
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

  TreasuryAccountUpdated treasuryAccountUpdated({_i3.AccountId32? oldAccount, required _i3.AccountId32 newAccount}) {
    return TreasuryAccountUpdated(oldAccount: oldAccount, newAccount: newAccount);
  }

  TreasuryPortionUpdated treasuryPortionUpdated({required _i4.Permill newPortion}) {
    return TreasuryPortionUpdated(newPortion: newPortion);
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return TreasuryAccountUpdated._decode(input);
      case 1:
        return TreasuryPortionUpdated._decode(input);
      default:
        throw Exception('Event: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Event value, _i1.Output output) {
    switch (value.runtimeType) {
      case TreasuryAccountUpdated:
        (value as TreasuryAccountUpdated).encodeTo(output);
        break;
      case TreasuryPortionUpdated:
        (value as TreasuryPortionUpdated).encodeTo(output);
        break;
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case TreasuryAccountUpdated:
        return (value as TreasuryAccountUpdated)._sizeHint();
      case TreasuryPortionUpdated:
        return (value as TreasuryPortionUpdated)._sizeHint();
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// The treasury account was updated.
///
/// Note: This only redirects where future mining rewards are sent. Any balance
/// accumulated in the old account remains there and is NOT automatically migrated.
/// Use a separate balance transfer if funds need to be moved.
class TreasuryAccountUpdated extends Event {
  const TreasuryAccountUpdated({this.oldAccount, required this.newAccount});

  factory TreasuryAccountUpdated._decode(_i1.Input input) {
    return TreasuryAccountUpdated(
      oldAccount: const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec()).decode(input),
      newAccount: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// Option<T::AccountId>
  /// The previous treasury account (None if this is the first time setting it).
  final _i3.AccountId32? oldAccount;

  /// T::AccountId
  /// The new treasury account that will receive future rewards.
  final _i3.AccountId32 newAccount;

  @override
  Map<String, Map<String, List<int>?>> toJson() => {
    'TreasuryAccountUpdated': {'oldAccount': oldAccount?.toList(), 'newAccount': newAccount.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec()).sizeHint(oldAccount);
    size = size + const _i3.AccountId32Codec().sizeHint(newAccount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    const _i1.OptionCodec<_i3.AccountId32>(_i3.AccountId32Codec()).encodeTo(oldAccount, output);
    const _i1.U8ArrayCodec(32).encodeTo(newAccount, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TreasuryAccountUpdated && other.oldAccount == oldAccount && _i5.listsEqual(other.newAccount, newAccount);

  @override
  int get hashCode => Object.hash(oldAccount, newAccount);
}

/// The treasury portion (share of mining rewards) was updated.
class TreasuryPortionUpdated extends Event {
  const TreasuryPortionUpdated({required this.newPortion});

  factory TreasuryPortionUpdated._decode(_i1.Input input) {
    return TreasuryPortionUpdated(newPortion: _i1.U32Codec.codec.decode(input));
  }

  /// Permill
  final _i4.Permill newPortion;

  @override
  Map<String, Map<String, int>> toJson() => {
    'TreasuryPortionUpdated': {'newPortion': newPortion},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i4.PermillCodec().sizeHint(newPortion);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    _i1.U32Codec.codec.encodeTo(newPortion, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TreasuryPortionUpdated && other.newPortion == newPortion;

  @override
  int get hashCode => newPortion.hashCode;
}
