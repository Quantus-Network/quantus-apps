// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i3;

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

  ProofSubmitted proofSubmitted({required List<int> nonce}) {
    return ProofSubmitted(nonce: nonce);
  }

  DifficultyAdjusted difficultyAdjusted({
    required BigInt oldDifficulty,
    required BigInt newDifficulty,
    required BigInt medianBlockTime,
  }) {
    return DifficultyAdjusted(
      oldDifficulty: oldDifficulty,
      newDifficulty: newDifficulty,
      medianBlockTime: medianBlockTime,
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
        return ProofSubmitted._decode(input);
      case 1:
        return DifficultyAdjusted._decode(input);
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
      case ProofSubmitted:
        (value as ProofSubmitted).encodeTo(output);
        break;
      case DifficultyAdjusted:
        (value as DifficultyAdjusted).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case ProofSubmitted:
        return (value as ProofSubmitted)._sizeHint();
      case DifficultyAdjusted:
        return (value as DifficultyAdjusted)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class ProofSubmitted extends Event {
  const ProofSubmitted({required this.nonce});

  factory ProofSubmitted._decode(_i1.Input input) {
    return ProofSubmitted(nonce: const _i1.U8ArrayCodec(64).decode(input));
  }

  /// [u8; 64]
  final List<int> nonce;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
        'ProofSubmitted': {'nonce': nonce.toList()}
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i1.U8ArrayCodec(64).sizeHint(nonce);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    const _i1.U8ArrayCodec(64).encodeTo(
      nonce,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ProofSubmitted &&
          _i3.listsEqual(
            other.nonce,
            nonce,
          );

  @override
  int get hashCode => nonce.hashCode;
}

class DifficultyAdjusted extends Event {
  const DifficultyAdjusted({
    required this.oldDifficulty,
    required this.newDifficulty,
    required this.medianBlockTime,
  });

  factory DifficultyAdjusted._decode(_i1.Input input) {
    return DifficultyAdjusted(
      oldDifficulty: _i1.U64Codec.codec.decode(input),
      newDifficulty: _i1.U64Codec.codec.decode(input),
      medianBlockTime: _i1.U64Codec.codec.decode(input),
    );
  }

  /// u64
  final BigInt oldDifficulty;

  /// u64
  final BigInt newDifficulty;

  /// u64
  final BigInt medianBlockTime;

  @override
  Map<String, Map<String, BigInt>> toJson() => {
        'DifficultyAdjusted': {
          'oldDifficulty': oldDifficulty,
          'newDifficulty': newDifficulty,
          'medianBlockTime': medianBlockTime,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(oldDifficulty);
    size = size + _i1.U64Codec.codec.sizeHint(newDifficulty);
    size = size + _i1.U64Codec.codec.sizeHint(medianBlockTime);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      oldDifficulty,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      newDifficulty,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      medianBlockTime,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is DifficultyAdjusted &&
          other.oldDifficulty == oldDifficulty &&
          other.newDifficulty == newDifficulty &&
          other.medianBlockTime == medianBlockTime;

  @override
  int get hashCode => Object.hash(
        oldDifficulty,
        newDifficulty,
        medianBlockTime,
      );
}
