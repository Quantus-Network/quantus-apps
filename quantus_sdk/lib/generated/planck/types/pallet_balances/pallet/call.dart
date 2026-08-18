// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../../sp_runtime/multiaddress/multi_address.dart' as _i3;

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

  TransferAllowDeath transferAllowDeath({required _i3.MultiAddress dest, required BigInt value}) {
    return TransferAllowDeath(dest: dest, value: value);
  }

  TransferKeepAlive transferKeepAlive({required _i3.MultiAddress dest, required BigInt value}) {
    return TransferKeepAlive(dest: dest, value: value);
  }

  TransferAll transferAll({required _i3.MultiAddress dest, required bool keepAlive}) {
    return TransferAll(dest: dest, keepAlive: keepAlive);
  }

  Burn burn({required BigInt value, required bool keepAlive}) {
    return Burn(value: value, keepAlive: keepAlive);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return TransferAllowDeath._decode(input);
      case 3:
        return TransferKeepAlive._decode(input);
      case 4:
        return TransferAll._decode(input);
      case 10:
        return Burn._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Call value, _i1.Output output) {
    switch (value.runtimeType) {
      case TransferAllowDeath:
        (value as TransferAllowDeath).encodeTo(output);
        break;
      case TransferKeepAlive:
        (value as TransferKeepAlive).encodeTo(output);
        break;
      case TransferAll:
        (value as TransferAll).encodeTo(output);
        break;
      case Burn:
        (value as Burn).encodeTo(output);
        break;
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case TransferAllowDeath:
        return (value as TransferAllowDeath)._sizeHint();
      case TransferKeepAlive:
        return (value as TransferKeepAlive)._sizeHint();
      case TransferAll:
        return (value as TransferAll)._sizeHint();
      case Burn:
        return (value as Burn)._sizeHint();
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Transfer some liquid free balance to another account.
///
/// `transfer_allow_death` will set the `FreeBalance` of the sender and receiver.
/// If the sender's account is below the existential deposit as a result
/// of the transfer, the account will be reaped.
///
/// The dispatch origin for this call must be `Signed` by the transactor.
class TransferAllowDeath extends Call {
  const TransferAllowDeath({required this.dest, required this.value});

  factory TransferAllowDeath._decode(_i1.Input input) {
    return TransferAllowDeath(
      dest: _i3.MultiAddress.codec.decode(input),
      value: _i1.CompactBigIntCodec.codec.decode(input),
    );
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress dest;

  /// T::Balance
  final BigInt value;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'transfer_allow_death': {'dest': dest.toJson(), 'value': value},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.CompactBigIntCodec.codec.sizeHint(value);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    _i3.MultiAddress.codec.encodeTo(dest, output);
    _i1.CompactBigIntCodec.codec.encodeTo(value, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TransferAllowDeath && other.dest == dest && other.value == value;

  @override
  int get hashCode => Object.hash(dest, value);
}

/// Same as the [`transfer_allow_death`] call, but with a check that the transfer will not
/// kill the origin account.
///
/// 99% of the time you want [`transfer_allow_death`] instead.
///
/// [`transfer_allow_death`]: struct.Pallet.html#method.transfer
class TransferKeepAlive extends Call {
  const TransferKeepAlive({required this.dest, required this.value});

  factory TransferKeepAlive._decode(_i1.Input input) {
    return TransferKeepAlive(
      dest: _i3.MultiAddress.codec.decode(input),
      value: _i1.CompactBigIntCodec.codec.decode(input),
    );
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress dest;

  /// T::Balance
  final BigInt value;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'transfer_keep_alive': {'dest': dest.toJson(), 'value': value},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.CompactBigIntCodec.codec.sizeHint(value);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(3, output);
    _i3.MultiAddress.codec.encodeTo(dest, output);
    _i1.CompactBigIntCodec.codec.encodeTo(value, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TransferKeepAlive && other.dest == dest && other.value == value;

  @override
  int get hashCode => Object.hash(dest, value);
}

/// Transfer the entire transferable balance from the caller account.
///
/// NOTE: This function only attempts to transfer _transferable_ balances. This means that
/// any locked, reserved, or existential deposits (when `keep_alive` is `true`), will not be
/// transferred by this function. To ensure that this function results in a killed account,
/// you might need to prepare the account by removing any reference counters, storage
/// deposits, etc...
///
/// The dispatch origin of this call must be Signed.
///
/// - `dest`: The recipient of the transfer.
/// - `keep_alive`: A boolean to determine if the `transfer_all` operation should send all
///  of the funds the account has, causing the sender account to be killed (false), or
///  transfer everything except at least the existential deposit, which will guarantee to
///  keep the sender account alive (true).
class TransferAll extends Call {
  const TransferAll({required this.dest, required this.keepAlive});

  factory TransferAll._decode(_i1.Input input) {
    return TransferAll(dest: _i3.MultiAddress.codec.decode(input), keepAlive: _i1.BoolCodec.codec.decode(input));
  }

  /// AccountIdLookupOf<T>
  final _i3.MultiAddress dest;

  /// bool
  final bool keepAlive;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'transfer_all': {'dest': dest.toJson(), 'keepAlive': keepAlive},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.BoolCodec.codec.sizeHint(keepAlive);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(4, output);
    _i3.MultiAddress.codec.encodeTo(dest, output);
    _i1.BoolCodec.codec.encodeTo(keepAlive, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TransferAll && other.dest == dest && other.keepAlive == keepAlive;

  @override
  int get hashCode => Object.hash(dest, keepAlive);
}

/// Burn the specified liquid free balance from the origin account.
///
/// If the origin's account ends up below the existential deposit as a result
/// of the burn and `keep_alive` is false, the account will be reaped.
///
/// Unlike sending funds to a _burn_ address, which merely makes the funds inaccessible,
/// this `burn` operation will reduce total issuance by the amount _burned_.
class Burn extends Call {
  const Burn({required this.value, required this.keepAlive});

  factory Burn._decode(_i1.Input input) {
    return Burn(value: _i1.CompactBigIntCodec.codec.decode(input), keepAlive: _i1.BoolCodec.codec.decode(input));
  }

  /// T::Balance
  final BigInt value;

  /// bool
  final bool keepAlive;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'burn': {'value': value, 'keepAlive': keepAlive},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.CompactBigIntCodec.codec.sizeHint(value);
    size = size + _i1.BoolCodec.codec.sizeHint(keepAlive);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(10, output);
    _i1.CompactBigIntCodec.codec.encodeTo(value, output);
    _i1.BoolCodec.codec.encodeTo(keepAlive, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Burn && other.value == value && other.keepAlive == keepAlive;

  @override
  int get hashCode => Object.hash(value, keepAlive);
}
