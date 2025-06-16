// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../frame_system/pallet/event.dart' as _i3;
import '../pallet_balances/pallet/event.dart' as _i4;
import '../pallet_conviction_voting/pallet/event.dart' as _i16;
import '../pallet_faucet/pallet/event.dart' as _i21;
import '../pallet_merkle_airdrop/pallet/event.dart' as _i19;
import '../pallet_mining_rewards/pallet/event.dart' as _i9;
import '../pallet_preimage/pallet/event.dart' as _i11;
import '../pallet_qpow/pallet/event.dart' as _i7;
import '../pallet_ranked_collective/pallet/event.dart' as _i17;
import '../pallet_recovery/pallet/event.dart' as _i22;
import '../pallet_referenda/pallet/event_1.dart' as _i14;
import '../pallet_referenda/pallet/event_2.dart' as _i18;
import '../pallet_reversible_transfers/pallet/event.dart' as _i15;
import '../pallet_scheduler/pallet/event.dart' as _i12;
import '../pallet_sudo/pallet/event.dart' as _i6;
import '../pallet_transaction_payment/pallet/event.dart' as _i5;
import '../pallet_treasury/pallet/event.dart' as _i20;
import '../pallet_utility/pallet/event.dart' as _i13;
import '../pallet_vesting/pallet/event.dart' as _i10;
import '../pallet_wormhole/pallet/event.dart' as _i8;

abstract class RuntimeEvent {
  const RuntimeEvent();

  factory RuntimeEvent.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $RuntimeEventCodec codec = $RuntimeEventCodec();

  static const $RuntimeEvent values = $RuntimeEvent();

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

class $RuntimeEvent {
  const $RuntimeEvent();

  System system(_i3.Event value0) {
    return System(value0);
  }

  Balances balances(_i4.Event value0) {
    return Balances(value0);
  }

  TransactionPayment transactionPayment(_i5.Event value0) {
    return TransactionPayment(value0);
  }

  Sudo sudo(_i6.Event value0) {
    return Sudo(value0);
  }

  QPoW qPoW(_i7.Event value0) {
    return QPoW(value0);
  }

  Wormhole wormhole(_i8.Event value0) {
    return Wormhole(value0);
  }

  MiningRewards miningRewards(_i9.Event value0) {
    return MiningRewards(value0);
  }

  Vesting vesting(_i10.Event value0) {
    return Vesting(value0);
  }

  Preimage preimage(_i11.Event value0) {
    return Preimage(value0);
  }

  Scheduler scheduler(_i12.Event value0) {
    return Scheduler(value0);
  }

  Utility utility(_i13.Event value0) {
    return Utility(value0);
  }

  Referenda referenda(_i14.Event value0) {
    return Referenda(value0);
  }

  ReversibleTransfers reversibleTransfers(_i15.Event value0) {
    return ReversibleTransfers(value0);
  }

  ConvictionVoting convictionVoting(_i16.Event value0) {
    return ConvictionVoting(value0);
  }

  TechCollective techCollective(_i17.Event value0) {
    return TechCollective(value0);
  }

  TechReferenda techReferenda(_i18.Event value0) {
    return TechReferenda(value0);
  }

  MerkleAirdrop merkleAirdrop(_i19.Event value0) {
    return MerkleAirdrop(value0);
  }

  TreasuryPallet treasuryPallet(_i20.Event value0) {
    return TreasuryPallet(value0);
  }

  Faucet faucet(_i21.Event value0) {
    return Faucet(value0);
  }

  Recovery recovery(_i22.Event value0) {
    return Recovery(value0);
  }
}

class $RuntimeEventCodec with _i1.Codec<RuntimeEvent> {
  const $RuntimeEventCodec();

  @override
  RuntimeEvent decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return System._decode(input);
      case 2:
        return Balances._decode(input);
      case 3:
        return TransactionPayment._decode(input);
      case 4:
        return Sudo._decode(input);
      case 5:
        return QPoW._decode(input);
      case 6:
        return Wormhole._decode(input);
      case 7:
        return MiningRewards._decode(input);
      case 8:
        return Vesting._decode(input);
      case 9:
        return Preimage._decode(input);
      case 10:
        return Scheduler._decode(input);
      case 11:
        return Utility._decode(input);
      case 12:
        return Referenda._decode(input);
      case 13:
        return ReversibleTransfers._decode(input);
      case 14:
        return ConvictionVoting._decode(input);
      case 15:
        return TechCollective._decode(input);
      case 16:
        return TechReferenda._decode(input);
      case 17:
        return MerkleAirdrop._decode(input);
      case 18:
        return TreasuryPallet._decode(input);
      case 19:
        return Faucet._decode(input);
      case 21:
        return Recovery._decode(input);
      default:
        throw Exception('RuntimeEvent: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    RuntimeEvent value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case System:
        (value as System).encodeTo(output);
        break;
      case Balances:
        (value as Balances).encodeTo(output);
        break;
      case TransactionPayment:
        (value as TransactionPayment).encodeTo(output);
        break;
      case Sudo:
        (value as Sudo).encodeTo(output);
        break;
      case QPoW:
        (value as QPoW).encodeTo(output);
        break;
      case Wormhole:
        (value as Wormhole).encodeTo(output);
        break;
      case MiningRewards:
        (value as MiningRewards).encodeTo(output);
        break;
      case Vesting:
        (value as Vesting).encodeTo(output);
        break;
      case Preimage:
        (value as Preimage).encodeTo(output);
        break;
      case Scheduler:
        (value as Scheduler).encodeTo(output);
        break;
      case Utility:
        (value as Utility).encodeTo(output);
        break;
      case Referenda:
        (value as Referenda).encodeTo(output);
        break;
      case ReversibleTransfers:
        (value as ReversibleTransfers).encodeTo(output);
        break;
      case ConvictionVoting:
        (value as ConvictionVoting).encodeTo(output);
        break;
      case TechCollective:
        (value as TechCollective).encodeTo(output);
        break;
      case TechReferenda:
        (value as TechReferenda).encodeTo(output);
        break;
      case MerkleAirdrop:
        (value as MerkleAirdrop).encodeTo(output);
        break;
      case TreasuryPallet:
        (value as TreasuryPallet).encodeTo(output);
        break;
      case Faucet:
        (value as Faucet).encodeTo(output);
        break;
      case Recovery:
        (value as Recovery).encodeTo(output);
        break;
      default:
        throw Exception(
            'RuntimeEvent: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(RuntimeEvent value) {
    switch (value.runtimeType) {
      case System:
        return (value as System)._sizeHint();
      case Balances:
        return (value as Balances)._sizeHint();
      case TransactionPayment:
        return (value as TransactionPayment)._sizeHint();
      case Sudo:
        return (value as Sudo)._sizeHint();
      case QPoW:
        return (value as QPoW)._sizeHint();
      case Wormhole:
        return (value as Wormhole)._sizeHint();
      case MiningRewards:
        return (value as MiningRewards)._sizeHint();
      case Vesting:
        return (value as Vesting)._sizeHint();
      case Preimage:
        return (value as Preimage)._sizeHint();
      case Scheduler:
        return (value as Scheduler)._sizeHint();
      case Utility:
        return (value as Utility)._sizeHint();
      case Referenda:
        return (value as Referenda)._sizeHint();
      case ReversibleTransfers:
        return (value as ReversibleTransfers)._sizeHint();
      case ConvictionVoting:
        return (value as ConvictionVoting)._sizeHint();
      case TechCollective:
        return (value as TechCollective)._sizeHint();
      case TechReferenda:
        return (value as TechReferenda)._sizeHint();
      case MerkleAirdrop:
        return (value as MerkleAirdrop)._sizeHint();
      case TreasuryPallet:
        return (value as TreasuryPallet)._sizeHint();
      case Faucet:
        return (value as Faucet)._sizeHint();
      case Recovery:
        return (value as Recovery)._sizeHint();
      default:
        throw Exception(
            'RuntimeEvent: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class System extends RuntimeEvent {
  const System(this.value0);

  factory System._decode(_i1.Input input) {
    return System(_i3.Event.codec.decode(input));
  }

  /// frame_system::Event<Runtime>
  final _i3.Event value0;

  @override
  Map<String, Map<String, dynamic>> toJson() => {'System': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i3.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i3.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is System && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Balances extends RuntimeEvent {
  const Balances(this.value0);

  factory Balances._decode(_i1.Input input) {
    return Balances(_i4.Event.codec.decode(input));
  }

  /// pallet_balances::Event<Runtime>
  final _i4.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'Balances': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i4.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      2,
      output,
    );
    _i4.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Balances && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class TransactionPayment extends RuntimeEvent {
  const TransactionPayment(this.value0);

  factory TransactionPayment._decode(_i1.Input input) {
    return TransactionPayment(_i5.Event.codec.decode(input));
  }

  /// pallet_transaction_payment::Event<Runtime>
  final _i5.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'TransactionPayment': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i5.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      3,
      output,
    );
    _i5.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is TransactionPayment && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Sudo extends RuntimeEvent {
  const Sudo(this.value0);

  factory Sudo._decode(_i1.Input input) {
    return Sudo(_i6.Event.codec.decode(input));
  }

  /// pallet_sudo::Event<Runtime>
  final _i6.Event value0;

  @override
  Map<String, Map<String, dynamic>> toJson() => {'Sudo': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i6.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      4,
      output,
    );
    _i6.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Sudo && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class QPoW extends RuntimeEvent {
  const QPoW(this.value0);

  factory QPoW._decode(_i1.Input input) {
    return QPoW(_i7.Event.codec.decode(input));
  }

  /// pallet_qpow::Event<Runtime>
  final _i7.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'QPoW': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i7.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      5,
      output,
    );
    _i7.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is QPoW && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Wormhole extends RuntimeEvent {
  const Wormhole(this.value0);

  factory Wormhole._decode(_i1.Input input) {
    return Wormhole(_i8.Event.codec.decode(input));
  }

  /// pallet_wormhole::Event<Runtime>
  final _i8.Event value0;

  @override
  Map<String, Map<String, Map<String, BigInt>>> toJson() =>
      {'Wormhole': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i8.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      6,
      output,
    );
    _i8.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Wormhole && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class MiningRewards extends RuntimeEvent {
  const MiningRewards(this.value0);

  factory MiningRewards._decode(_i1.Input input) {
    return MiningRewards(_i9.Event.codec.decode(input));
  }

  /// pallet_mining_rewards::Event<Runtime>
  final _i9.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'MiningRewards': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i9.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      7,
      output,
    );
    _i9.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is MiningRewards && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Vesting extends RuntimeEvent {
  const Vesting(this.value0);

  factory Vesting._decode(_i1.Input input) {
    return Vesting(_i10.Event.codec.decode(input));
  }

  /// pallet_vesting::Event<Runtime>
  final _i10.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'Vesting': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i10.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      8,
      output,
    );
    _i10.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Vesting && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Preimage extends RuntimeEvent {
  const Preimage(this.value0);

  factory Preimage._decode(_i1.Input input) {
    return Preimage(_i11.Event.codec.decode(input));
  }

  /// pallet_preimage::Event<Runtime>
  final _i11.Event value0;

  @override
  Map<String, Map<String, Map<String, List<int>>>> toJson() =>
      {'Preimage': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i11.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      9,
      output,
    );
    _i11.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Preimage && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Scheduler extends RuntimeEvent {
  const Scheduler(this.value0);

  factory Scheduler._decode(_i1.Input input) {
    return Scheduler(_i12.Event.codec.decode(input));
  }

  /// pallet_scheduler::Event<Runtime>
  final _i12.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'Scheduler': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i12.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      10,
      output,
    );
    _i12.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Scheduler && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Utility extends RuntimeEvent {
  const Utility(this.value0);

  factory Utility._decode(_i1.Input input) {
    return Utility(_i13.Event.codec.decode(input));
  }

  /// pallet_utility::Event
  final _i13.Event value0;

  @override
  Map<String, Map<String, dynamic>> toJson() => {'Utility': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i13.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      11,
      output,
    );
    _i13.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Utility && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Referenda extends RuntimeEvent {
  const Referenda(this.value0);

  factory Referenda._decode(_i1.Input input) {
    return Referenda(_i14.Event.codec.decode(input));
  }

  /// pallet_referenda::Event<Runtime>
  final _i14.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'Referenda': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i14.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      12,
      output,
    );
    _i14.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Referenda && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class ReversibleTransfers extends RuntimeEvent {
  const ReversibleTransfers(this.value0);

  factory ReversibleTransfers._decode(_i1.Input input) {
    return ReversibleTransfers(_i15.Event.codec.decode(input));
  }

  /// pallet_reversible_transfers::Event<Runtime>
  final _i15.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'ReversibleTransfers': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i15.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      13,
      output,
    );
    _i15.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ReversibleTransfers && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class ConvictionVoting extends RuntimeEvent {
  const ConvictionVoting(this.value0);

  factory ConvictionVoting._decode(_i1.Input input) {
    return ConvictionVoting(_i16.Event.codec.decode(input));
  }

  /// pallet_conviction_voting::Event<Runtime>
  final _i16.Event value0;

  @override
  Map<String, Map<String, dynamic>> toJson() =>
      {'ConvictionVoting': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i16.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      14,
      output,
    );
    _i16.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ConvictionVoting && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class TechCollective extends RuntimeEvent {
  const TechCollective(this.value0);

  factory TechCollective._decode(_i1.Input input) {
    return TechCollective(_i17.Event.codec.decode(input));
  }

  /// pallet_ranked_collective::Event<Runtime>
  final _i17.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'TechCollective': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i17.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      15,
      output,
    );
    _i17.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is TechCollective && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class TechReferenda extends RuntimeEvent {
  const TechReferenda(this.value0);

  factory TechReferenda._decode(_i1.Input input) {
    return TechReferenda(_i18.Event.codec.decode(input));
  }

  /// pallet_referenda::Event<Runtime, pallet_referenda::Instance1>
  final _i18.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'TechReferenda': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i18.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      16,
      output,
    );
    _i18.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is TechReferenda && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class MerkleAirdrop extends RuntimeEvent {
  const MerkleAirdrop(this.value0);

  factory MerkleAirdrop._decode(_i1.Input input) {
    return MerkleAirdrop(_i19.Event.codec.decode(input));
  }

  /// pallet_merkle_airdrop::Event<Runtime>
  final _i19.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'MerkleAirdrop': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i19.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      17,
      output,
    );
    _i19.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is MerkleAirdrop && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class TreasuryPallet extends RuntimeEvent {
  const TreasuryPallet(this.value0);

  factory TreasuryPallet._decode(_i1.Input input) {
    return TreasuryPallet(_i20.Event.codec.decode(input));
  }

  /// pallet_treasury::Event<Runtime>
  final _i20.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'TreasuryPallet': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i20.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      18,
      output,
    );
    _i20.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is TreasuryPallet && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Faucet extends RuntimeEvent {
  const Faucet(this.value0);

  factory Faucet._decode(_i1.Input input) {
    return Faucet(_i21.Event.codec.decode(input));
  }

  /// pallet_faucet::Event<Runtime>
  final _i21.Event value0;

  @override
  Map<String, Map<String, Map<String, dynamic>>> toJson() =>
      {'Faucet': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i21.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      19,
      output,
    );
    _i21.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Faucet && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}

class Recovery extends RuntimeEvent {
  const Recovery(this.value0);

  factory Recovery._decode(_i1.Input input) {
    return Recovery(_i22.Event.codec.decode(input));
  }

  /// pallet_recovery::Event<Runtime>
  final _i22.Event value0;

  @override
  Map<String, Map<String, Map<String, List<int>>>> toJson() =>
      {'Recovery': value0.toJson()};

  int _sizeHint() {
    int size = 1;
    size = size + _i22.Event.codec.sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      21,
      output,
    );
    _i22.Event.codec.encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Recovery && other.value0 == value0;

  @override
  int get hashCode => value0.hashCode;
}
