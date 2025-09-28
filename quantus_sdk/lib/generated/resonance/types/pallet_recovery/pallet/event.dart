// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i3;

/// Events type.
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

  Map<String, Map<String, List<int>>> toJson();
}

class $Event {
  const $Event();

  RecoveryCreated recoveryCreated({required _i3.AccountId32 account}) {
    return RecoveryCreated(account: account);
  }

  RecoveryInitiated recoveryInitiated({
    required _i3.AccountId32 lostAccount,
    required _i3.AccountId32 rescuerAccount,
  }) {
    return RecoveryInitiated(
      lostAccount: lostAccount,
      rescuerAccount: rescuerAccount,
    );
  }

  RecoveryVouched recoveryVouched({
    required _i3.AccountId32 lostAccount,
    required _i3.AccountId32 rescuerAccount,
    required _i3.AccountId32 sender,
  }) {
    return RecoveryVouched(
      lostAccount: lostAccount,
      rescuerAccount: rescuerAccount,
      sender: sender,
    );
  }

  RecoveryClosed recoveryClosed({
    required _i3.AccountId32 lostAccount,
    required _i3.AccountId32 rescuerAccount,
  }) {
    return RecoveryClosed(
      lostAccount: lostAccount,
      rescuerAccount: rescuerAccount,
    );
  }

  AccountRecovered accountRecovered({
    required _i3.AccountId32 lostAccount,
    required _i3.AccountId32 rescuerAccount,
  }) {
    return AccountRecovered(
      lostAccount: lostAccount,
      rescuerAccount: rescuerAccount,
    );
  }

  RecoveryRemoved recoveryRemoved({required _i3.AccountId32 lostAccount}) {
    return RecoveryRemoved(lostAccount: lostAccount);
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return RecoveryCreated._decode(input);
      case 1:
        return RecoveryInitiated._decode(input);
      case 2:
        return RecoveryVouched._decode(input);
      case 3:
        return RecoveryClosed._decode(input);
      case 4:
        return AccountRecovered._decode(input);
      case 5:
        return RecoveryRemoved._decode(input);
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
      case RecoveryCreated:
        (value as RecoveryCreated).encodeTo(output);
        break;
      case RecoveryInitiated:
        (value as RecoveryInitiated).encodeTo(output);
        break;
      case RecoveryVouched:
        (value as RecoveryVouched).encodeTo(output);
        break;
      case RecoveryClosed:
        (value as RecoveryClosed).encodeTo(output);
        break;
      case AccountRecovered:
        (value as AccountRecovered).encodeTo(output);
        break;
      case RecoveryRemoved:
        (value as RecoveryRemoved).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case RecoveryCreated:
        return (value as RecoveryCreated)._sizeHint();
      case RecoveryInitiated:
        return (value as RecoveryInitiated)._sizeHint();
      case RecoveryVouched:
        return (value as RecoveryVouched)._sizeHint();
      case RecoveryClosed:
        return (value as RecoveryClosed)._sizeHint();
      case AccountRecovered:
        return (value as AccountRecovered)._sizeHint();
      case RecoveryRemoved:
        return (value as RecoveryRemoved)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A recovery process has been set up for an account.
class RecoveryCreated extends Event {
  const RecoveryCreated({required this.account});

  factory RecoveryCreated._decode(_i1.Input input) {
    return RecoveryCreated(account: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::AccountId
  final _i3.AccountId32 account;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'RecoveryCreated': {'account': account.toList()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(account);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      account,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RecoveryCreated &&
          _i4.listsEqual(
            other.account,
            account,
          );

  @override
  int get hashCode => account.hashCode;
}

/// A recovery process has been initiated for lost account by rescuer account.
class RecoveryInitiated extends Event {
  const RecoveryInitiated({
    required this.lostAccount,
    required this.rescuerAccount,
  });

  factory RecoveryInitiated._decode(_i1.Input input) {
    return RecoveryInitiated(
      lostAccount: const _i1.U8ArrayCodec(32).decode(input),
      rescuerAccount: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 lostAccount;

  /// T::AccountId
  final _i3.AccountId32 rescuerAccount;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'RecoveryInitiated': {
          'lostAccount': lostAccount.toList(),
          'rescuerAccount': rescuerAccount.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(lostAccount);
    size = size + const _i3.AccountId32Codec().sizeHint(rescuerAccount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      lostAccount,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      rescuerAccount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RecoveryInitiated &&
          _i4.listsEqual(
            other.lostAccount,
            lostAccount,
          ) &&
          _i4.listsEqual(
            other.rescuerAccount,
            rescuerAccount,
          );

  @override
  int get hashCode => Object.hash(
        lostAccount,
        rescuerAccount,
      );
}

/// A recovery process for lost account by rescuer account has been vouched for by sender.
class RecoveryVouched extends Event {
  const RecoveryVouched({
    required this.lostAccount,
    required this.rescuerAccount,
    required this.sender,
  });

  factory RecoveryVouched._decode(_i1.Input input) {
    return RecoveryVouched(
      lostAccount: const _i1.U8ArrayCodec(32).decode(input),
      rescuerAccount: const _i1.U8ArrayCodec(32).decode(input),
      sender: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 lostAccount;

  /// T::AccountId
  final _i3.AccountId32 rescuerAccount;

  /// T::AccountId
  final _i3.AccountId32 sender;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'RecoveryVouched': {
          'lostAccount': lostAccount.toList(),
          'rescuerAccount': rescuerAccount.toList(),
          'sender': sender.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(lostAccount);
    size = size + const _i3.AccountId32Codec().sizeHint(rescuerAccount);
    size = size + const _i3.AccountId32Codec().sizeHint(sender);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      lostAccount,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      rescuerAccount,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      sender,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RecoveryVouched &&
          _i4.listsEqual(
            other.lostAccount,
            lostAccount,
          ) &&
          _i4.listsEqual(
            other.rescuerAccount,
            rescuerAccount,
          ) &&
          _i4.listsEqual(
            other.sender,
            sender,
          );

  @override
  int get hashCode => Object.hash(
        lostAccount,
        rescuerAccount,
        sender,
      );
}

/// A recovery process for lost account by rescuer account has been closed.
class RecoveryClosed extends Event {
  const RecoveryClosed({
    required this.lostAccount,
    required this.rescuerAccount,
  });

  factory RecoveryClosed._decode(_i1.Input input) {
    return RecoveryClosed(
      lostAccount: const _i1.U8ArrayCodec(32).decode(input),
      rescuerAccount: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 lostAccount;

  /// T::AccountId
  final _i3.AccountId32 rescuerAccount;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'RecoveryClosed': {
          'lostAccount': lostAccount.toList(),
          'rescuerAccount': rescuerAccount.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(lostAccount);
    size = size + const _i3.AccountId32Codec().sizeHint(rescuerAccount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      lostAccount,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      rescuerAccount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RecoveryClosed &&
          _i4.listsEqual(
            other.lostAccount,
            lostAccount,
          ) &&
          _i4.listsEqual(
            other.rescuerAccount,
            rescuerAccount,
          );

  @override
  int get hashCode => Object.hash(
        lostAccount,
        rescuerAccount,
      );
}

/// Lost account has been successfully recovered by rescuer account.
class AccountRecovered extends Event {
  const AccountRecovered({
    required this.lostAccount,
    required this.rescuerAccount,
  });

  factory AccountRecovered._decode(_i1.Input input) {
    return AccountRecovered(
      lostAccount: const _i1.U8ArrayCodec(32).decode(input),
      rescuerAccount: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 lostAccount;

  /// T::AccountId
  final _i3.AccountId32 rescuerAccount;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'AccountRecovered': {
          'lostAccount': lostAccount.toList(),
          'rescuerAccount': rescuerAccount.toList(),
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(lostAccount);
    size = size + const _i3.AccountId32Codec().sizeHint(rescuerAccount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      4,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      lostAccount,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      rescuerAccount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is AccountRecovered &&
          _i4.listsEqual(
            other.lostAccount,
            lostAccount,
          ) &&
          _i4.listsEqual(
            other.rescuerAccount,
            rescuerAccount,
          );

  @override
  int get hashCode => Object.hash(
        lostAccount,
        rescuerAccount,
      );
}

/// A recovery process has been removed for an account.
class RecoveryRemoved extends Event {
  const RecoveryRemoved({required this.lostAccount});

  factory RecoveryRemoved._decode(_i1.Input input) {
    return RecoveryRemoved(
        lostAccount: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::AccountId
  final _i3.AccountId32 lostAccount;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'RecoveryRemoved': {'lostAccount': lostAccount.toList()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(lostAccount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      5,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      lostAccount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RecoveryRemoved &&
          _i4.listsEqual(
            other.lostAccount,
            lostAccount,
          );

  @override
  int get hashCode => lostAccount.hashCode;
}
