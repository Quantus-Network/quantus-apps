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

  ProofSubmitted proofSubmitted({required List<int> nonce}) {
    return ProofSubmitted(nonce: nonce);
  }

  DistanceThresholdAdjusted distanceThresholdAdjusted({
    required _i3.U512 oldDistanceThreshold,
    required _i3.U512 newDistanceThreshold,
    required BigInt observedBlockTime,
  }) {
    return DistanceThresholdAdjusted(
      oldDistanceThreshold: oldDistanceThreshold,
      newDistanceThreshold: newDistanceThreshold,
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
        return DistanceThresholdAdjusted._decode(input);
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
      case DistanceThresholdAdjusted:
        (value as DistanceThresholdAdjusted).encodeTo(output);
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
      case DistanceThresholdAdjusted:
        return (value as DistanceThresholdAdjusted)._sizeHint();
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
          _i4.listsEqual(
            other.nonce,
            nonce,
          );

  @override
  int get hashCode => nonce.hashCode;
}

class DistanceThresholdAdjusted extends Event {
  const DistanceThresholdAdjusted({
    required this.oldDistanceThreshold,
    required this.newDistanceThreshold,
    required this.observedBlockTime,
  });

  factory DistanceThresholdAdjusted._decode(_i1.Input input) {
    return DistanceThresholdAdjusted(
      oldDistanceThreshold: const _i1.U64ArrayCodec(8).decode(input),
      newDistanceThreshold: const _i1.U64ArrayCodec(8).decode(input),
      observedBlockTime: _i1.U64Codec.codec.decode(input),
    );
  }

  /// U512
  final _i3.U512 oldDistanceThreshold;

  /// U512
  final _i3.U512 newDistanceThreshold;

  /// u64
  final BigInt observedBlockTime;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'DistanceThresholdAdjusted': {
          'oldDistanceThreshold': oldDistanceThreshold.toList(),
          'newDistanceThreshold': newDistanceThreshold.toList(),
          'observedBlockTime': observedBlockTime,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.U512Codec().sizeHint(oldDistanceThreshold);
    size = size + const _i3.U512Codec().sizeHint(newDistanceThreshold);
    size = size + _i1.U64Codec.codec.sizeHint(observedBlockTime);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U64ArrayCodec(8).encodeTo(
      oldDistanceThreshold,
      output,
    );
    const _i1.U64ArrayCodec(8).encodeTo(
      newDistanceThreshold,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      observedBlockTime,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is DistanceThresholdAdjusted &&
          _i4.listsEqual(
            other.oldDistanceThreshold,
            oldDistanceThreshold,
          ) &&
          _i4.listsEqual(
            other.newDistanceThreshold,
            newDistanceThreshold,
          ) &&
          other.observedBlockTime == observedBlockTime;

  @override
  int get hashCode => Object.hash(
        oldDistanceThreshold,
        newDistanceThreshold,
        observedBlockTime,
      );
}
