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

  MinerRewarded minerRewarded({
    required int block,
    required _i3.AccountId32 miner,
    required BigInt reward,
  }) {
    return MinerRewarded(
      block: block,
      miner: miner,
      reward: reward,
    );
  }

  FeesCollected feesCollected({
    required BigInt amount,
    required BigInt total,
  }) {
    return FeesCollected(
      amount: amount,
      total: total,
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
        return MinerRewarded._decode(input);
      case 1:
        return FeesCollected._decode(input);
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
      case MinerRewarded:
        (value as MinerRewarded).encodeTo(output);
        break;
      case FeesCollected:
        (value as FeesCollected).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case MinerRewarded:
        return (value as MinerRewarded)._sizeHint();
      case FeesCollected:
        return (value as FeesCollected)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A miner has been identified for a block
class MinerRewarded extends Event {
  const MinerRewarded({
    required this.block,
    required this.miner,
    required this.reward,
  });

  factory MinerRewarded._decode(_i1.Input input) {
    return MinerRewarded(
      block: _i1.U32Codec.codec.decode(input),
      miner: const _i1.U8ArrayCodec(32).decode(input),
      reward: _i1.U128Codec.codec.decode(input),
    );
  }

  /// BlockNumberFor<T>
  /// Block number
  final int block;

  /// T::AccountId
  /// Miner account
  final _i3.AccountId32 miner;

  /// BalanceOf<T>
  /// Total reward (base + fees)
  final BigInt reward;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'MinerRewarded': {
          'block': block,
          'miner': miner.toList(),
          'reward': reward,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U32Codec.codec.sizeHint(block);
    size = size + const _i3.AccountId32Codec().sizeHint(miner);
    size = size + _i1.U128Codec.codec.sizeHint(reward);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      block,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      miner,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      reward,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is MinerRewarded &&
          other.block == block &&
          _i4.listsEqual(
            other.miner,
            miner,
          ) &&
          other.reward == reward;

  @override
  int get hashCode => Object.hash(
        block,
        miner,
        reward,
      );
}

/// Transaction fees were collected for later distribution
class FeesCollected extends Event {
  const FeesCollected({
    required this.amount,
    required this.total,
  });

  factory FeesCollected._decode(_i1.Input input) {
    return FeesCollected(
      amount: _i1.U128Codec.codec.decode(input),
      total: _i1.U128Codec.codec.decode(input),
    );
  }

  /// BalanceOf<T>
  /// The amount collected
  final BigInt amount;

  /// BalanceOf<T>
  /// Total fees waiting for distribution
  final BigInt total;

  @override
  Map<String, Map<String, BigInt>> toJson() => {
        'FeesCollected': {
          'amount': amount,
          'total': total,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U128Codec.codec.sizeHint(amount);
    size = size + _i1.U128Codec.codec.sizeHint(total);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      amount,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      total,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is FeesCollected && other.amount == amount && other.total == total;

  @override
  int get hashCode => Object.hash(
        amount,
        total,
      );
}
