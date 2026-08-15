// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../frame_system/pallet/call.dart' as _i3;
import '../pallet_balances/pallet/call.dart' as _i5;
import '../pallet_multisig/pallet/call.dart' as _i13;
import '../pallet_preimage/pallet/call.dart' as _i6;
import '../pallet_ranked_collective/pallet/call.dart' as _i9;
import '../pallet_recovery/pallet/call.dart' as _i12;
import '../pallet_referenda/pallet/call.dart' as _i10;
import '../pallet_reversible_transfers/pallet/call.dart' as _i8;
import '../pallet_timestamp/pallet/call.dart' as _i4;
import '../pallet_treasury/pallet/call.dart' as _i11;
import '../pallet_utility/pallet/call.dart' as _i7;
import '../pallet_vesting/pallet/call.dart' as _i15;
import '../pallet_wormhole/pallet/call.dart' as _i14;

abstract class RuntimeCall {
  const RuntimeCall();

  factory RuntimeCall.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $RuntimeCallCodec codec = $RuntimeCallCodec();

  static const $RuntimeCall values = $RuntimeCall();

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

class $RuntimeCall {
  const $RuntimeCall();

  System system(_i3.Call value0) {
    return System(value0);
  }

  Timestamp timestamp(_i4.Call value0) {
    return Timestamp(value0);
  }

  Balances balances(_i5.Call value0) {
    return Balances(value0);
  }

  Preimage preimage(_i6.Call value0) {
    return Preimage(value0);
  }

  Utility utility(_i7.Call value0) {
    return Utility(value0);
  }

  ReversibleTransfers reversibleTransfers(_i8.Call value0) {
    return ReversibleTransfers(value0);
  }

  TechCollective techCollective(_i9.Call value0) {
    return TechCollective(value0);
  }

  TechReferenda techReferenda(_i10.Call value0) {
    return TechReferenda(value0);
  }

  TreasuryPallet treasuryPallet(_i11.Call value0) {
    return TreasuryPallet(value0);
  }

  Recovery recovery(_i12.Call value0) {
    return Recovery(value0);
  }

  Multisig multisig(_i13.Call value0) {
    return Multisig(value0);
  }

  Wormhole wormhole(_i14.Call value0) {
    return Wormhole(value0);
  }

  Vesting vesting(_i15.Call value0) {
    return Vesting(value0);
  }
}

class $RuntimeCallCodec with _i1.Codec<RuntimeCall> {
  const $RuntimeCallCodec();

  @override
  RuntimeCall decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return System._decode(input);
      case 1:
        return Timestamp._decode(input);
      case 2:
        return Balances._decode(input);
      case 7:
        return Preimage._decode(input);
      case 9:
        return Utility._decode(input);
      case 11:
        return ReversibleTransfers._decode(input);
      case 13:
        return TechCollective._decode(input);
      case 14:
        return TechReferenda._decode(input);
      case 15:
        return TreasuryPallet._decode(input);
      case 16:
        return Recovery._decode(input);
      case 19:
        return Multisig._decode(input);
      case 20:
        return Wormhole._decode(input);
      case 22:
        return Vesting._decode(input);
      default:
        throw Exception('RuntimeCall: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(RuntimeCall value, _i1.Output output) {
    switch (value.runtimeType) {
      case System:
        (value as System).encodeTo(output);
        break;
      case Timestamp:
        (value as Timestamp).encodeTo(output);
        break;
      case Balances:
        (value as Balances).encodeTo(output);
        break;
      case Preimage:
        (value as Preimage).encodeTo(output);
        break;
      case Utility:
        (value as Utility).encodeTo(output);
        break;
      case ReversibleTransfers:
        (value as ReversibleTransfers).encodeTo(output);
        break;
      case TechCollective:
        (value as TechCollective).encodeTo(output);
        break;
      case TechReferenda:
        (value as TechReferenda).encodeTo(output);
        break;
      case TreasuryPallet:
        (value as TreasuryPallet).encodeTo(output);
        break;
      case Recovery:
        (value as Recovery).encodeTo(output);
        break;
      case Multisig:
        (value as Multisig).encodeTo(output);
        break;
      case Wormhole:
        (value as Wormhole).encodeTo(output);
        break;
      case Vesting:
        (value as Vesting).encodeTo(output);
        break;
      default:
        throw Exception('RuntimeCall: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(RuntimeCall value) {
    switch (value.runtimeType) {
      case System:
        return (value as System)._sizeHint();
      case Timestamp:
        return (value as Timestamp)._sizeHint();
      case Balances:
        return (value as Balances)._sizeHint();
      case Preimage:
        return (value as Preimage)._sizeHint();
      case Utility:
        return (value as Utility)._sizeHint();
      case ReversibleTransfers:
        return (value as ReversibleTransfers)._sizeHint();
      case TechCollective:
        return (value as TechCollective)._sizeHint();
      case TechReferenda:
        return (value as TechReferenda)._sizeHint();
      case TreasuryPallet:
        return (value as TreasuryPallet)._sizeHint();
      case Recovery:
        return (value as Recovery)._sizeHint();
      case Multisig:
        return (value as Multisig)._sizeHint();
      case Wormhole:
        return (value as Wormhole)._sizeHint();
      case Vesting:
        return (value as Vesting)._sizeHint();
      default:
        throw Exception('RuntimeCall: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class System extends RuntimeCall {
  const System(this.value0);

  factory System._decode(_i1.Input input) {
    return System(_i3.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<System, Runtime>
  final _i3.Call value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {'System': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i3.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    _i3.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is System && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Timestamp extends RuntimeCall {
  const Timestamp(this.value0);

  factory Timestamp._decode(_i1.Input input) {
    return Timestamp(_i4.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<Timestamp, Runtime>
  final _i4.Call value0;

  @override
  Map<String, Map<String, Map<String, BigInt>>> toJson() => {'Timestamp': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i4.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    _i4.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Timestamp && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Balances extends RuntimeCall {
  const Balances(this.value0);

  factory Balances._decode(_i1.Input input) {
    return Balances(_i5.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<Balances, Runtime>
  final _i5.Call value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {'Balances': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i5.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    _i5.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Balances && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Preimage extends RuntimeCall {
  const Preimage(this.value0);

  factory Preimage._decode(_i1.Input input) {
    return Preimage(_i6.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<Preimage, Runtime>
  final _i6.Call value0;

  @override
  Map<String, Map<String, Map<String, List<dynamic>>>> toJson() => {'Preimage': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i6.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(7, output);
    _i6.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Preimage && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Utility extends RuntimeCall {
  const Utility(this.value0);

  factory Utility._decode(_i1.Input input) {
    return Utility(_i7.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<Utility, Runtime>
  final _i7.Call value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {'Utility': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i7.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(9, output);
    _i7.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Utility && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class ReversibleTransfers extends RuntimeCall {
  const ReversibleTransfers(this.value0);

  factory ReversibleTransfers._decode(_i1.Input input) {
    return ReversibleTransfers(_i8.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<ReversibleTransfers, Runtime>
  final _i8.Call value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {'ReversibleTransfers': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i8.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(11, output);
    _i8.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is ReversibleTransfers && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class TechCollective extends RuntimeCall {
  const TechCollective(this.value0);

  factory TechCollective._decode(_i1.Input input) {
    return TechCollective(_i9.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<TechCollective, Runtime>
  final _i9.Call value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {'TechCollective': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i9.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(13, output);
    _i9.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is TechCollective && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class TechReferenda extends RuntimeCall {
  const TechReferenda(this.value0);

  factory TechReferenda._decode(_i1.Input input) {
    return TechReferenda(_i10.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<TechReferenda, Runtime>
  final _i10.Call value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {'TechReferenda': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i10.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(14, output);
    _i10.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is TechReferenda && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class TreasuryPallet extends RuntimeCall {
  const TreasuryPallet(this.value0);

  factory TreasuryPallet._decode(_i1.Input input) {
    return TreasuryPallet(_i11.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<TreasuryPallet, Runtime>
  final _i11.Call value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {'TreasuryPallet': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i11.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(15, output);
    _i11.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is TreasuryPallet && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Recovery extends RuntimeCall {
  const Recovery(this.value0);

  factory Recovery._decode(_i1.Input input) {
    return Recovery(_i12.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<Recovery, Runtime>
  final _i12.Call value0;

  @override
  Map<String, Map<String, dynamic>> toJson() => {'Recovery': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i12.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(16, output);
    _i12.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Recovery && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Multisig extends RuntimeCall {
  const Multisig(this.value0);

  factory Multisig._decode(_i1.Input input) {
    return Multisig(_i13.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<Multisig, Runtime>
  final _i13.Call value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {'Multisig': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i13.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(19, output);
    _i13.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Multisig && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Wormhole extends RuntimeCall {
  const Wormhole(this.value0);

  factory Wormhole._decode(_i1.Input input) {
    return Wormhole(_i14.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<Wormhole, Runtime>
  final _i14.Call value0;

  @override
  Map<String, Map<String, Map<String, List<int>>>> toJson() => {'Wormhole': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i14.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(20, output);
    _i14.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Wormhole && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Vesting extends RuntimeCall {
  const Vesting(this.value0);

  factory Vesting._decode(_i1.Input input) {
    return Vesting(_i15.Call.codec.decode(input));
  }

  /// self::sp_api_hidden_includes_construct_runtime::hidden_include::dispatch
  ///::CallableCallFor<Vesting, Runtime>
  final _i15.Call value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() => {'Vesting': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i15.Call.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(22, output);
    _i15.Call.codec.encodeTo(value0, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Vesting && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}
