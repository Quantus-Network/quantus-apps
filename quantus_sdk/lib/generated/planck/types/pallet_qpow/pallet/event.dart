// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../primitive_types/u512.dart' as _i3;

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

  ProofSubmitted proofSubmitted({
    required List<int> nonce,
    required _i3.U512 difficulty,
    required _i3.U512 hashAchieved,
  }) {
    return ProofSubmitted(nonce: nonce, difficulty: difficulty, hashAchieved: hashAchieved);
  }

  DifficultyAdjusted difficultyAdjusted({
    required _i3.U512 oldDifficulty,
    required _i3.U512 newDifficulty,
    required BigInt observedBlockTime,
  }) {
    return DifficultyAdjusted(
      oldDifficulty: oldDifficulty,
      newDifficulty: newDifficulty,
      observedBlockTime: observedBlockTime,
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
  void encodeTo(Event value, _i1.Output output) {
    switch (value.runtimeType) {
      case ProofSubmitted:
        (value as ProofSubmitted).encodeTo(output);
        break;
      case DifficultyAdjusted:
        (value as DifficultyAdjusted).encodeTo(output);
        break;
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
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
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class ProofSubmitted extends Event {
  const ProofSubmitted({required this.nonce, required this.difficulty, required this.hashAchieved});

  factory ProofSubmitted._decode(_i1.Input input) {
    return ProofSubmitted(
      nonce: const _i1.U8ArrayCodec(64).decode(input),
      difficulty: const _i1.U64ArrayCodec(8).decode(input),
      hashAchieved: const _i1.U64ArrayCodec(8).decode(input),
    );
  }

  /// NonceType
  final List<int> nonce;

  /// U512
  final _i3.U512 difficulty;

  /// U512
  final _i3.U512 hashAchieved;

  @override
  Map<String, Map<String, List<dynamic>>> toJson() => {
    'ProofSubmitted': {
      'nonce': nonce.toList(),
      'difficulty': difficulty.toList(),
      'hashAchieved': hashAchieved.toList(),
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i1.U8ArrayCodec(64).sizeHint(nonce);
    size = size + const _i3.U512Codec().sizeHint(difficulty);
    size = size + const _i3.U512Codec().sizeHint(hashAchieved);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    const _i1.U8ArrayCodec(64).encodeTo(nonce, output);
    const _i1.U64ArrayCodec(8).encodeTo(difficulty, output);
    const _i1.U64ArrayCodec(8).encodeTo(hashAchieved, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProofSubmitted &&
          _i4.listsEqual(other.nonce, nonce) &&
          _i4.listsEqual(other.difficulty, difficulty) &&
          _i4.listsEqual(other.hashAchieved, hashAchieved);

  @override
  int get hashCode => Object.hash(nonce, difficulty, hashAchieved);
}

class DifficultyAdjusted extends Event {
  const DifficultyAdjusted({required this.oldDifficulty, required this.newDifficulty, required this.observedBlockTime});

  factory DifficultyAdjusted._decode(_i1.Input input) {
    return DifficultyAdjusted(
      oldDifficulty: const _i1.U64ArrayCodec(8).decode(input),
      newDifficulty: const _i1.U64ArrayCodec(8).decode(input),
      observedBlockTime: _i1.U64Codec.codec.decode(input),
    );
  }

  /// Difficulty
  final _i3.U512 oldDifficulty;

  /// Difficulty
  final _i3.U512 newDifficulty;

  /// BlockDuration
  final BigInt observedBlockTime;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'DifficultyAdjusted': {
      'oldDifficulty': oldDifficulty.toList(),
      'newDifficulty': newDifficulty.toList(),
      'observedBlockTime': observedBlockTime,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.U512Codec().sizeHint(oldDifficulty);
    size = size + const _i3.U512Codec().sizeHint(newDifficulty);
    size = size + _i1.U64Codec.codec.sizeHint(observedBlockTime);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    const _i1.U64ArrayCodec(8).encodeTo(oldDifficulty, output);
    const _i1.U64ArrayCodec(8).encodeTo(newDifficulty, output);
    _i1.U64Codec.codec.encodeTo(observedBlockTime, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DifficultyAdjusted &&
          _i4.listsEqual(other.oldDifficulty, oldDifficulty) &&
          _i4.listsEqual(other.newDifficulty, newDifficulty) &&
          other.observedBlockTime == observedBlockTime;

  @override
  int get hashCode => Object.hash(oldDifficulty, newDifficulty, observedBlockTime);
}
