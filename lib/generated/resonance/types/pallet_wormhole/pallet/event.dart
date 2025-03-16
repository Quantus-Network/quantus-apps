// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

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

  Map<String, Map<String, BigInt>> toJson();
}

class $Event {
  const $Event();

  ProofVerified proofVerified({required BigInt exitAmount}) {
    return ProofVerified(exitAmount: exitAmount);
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return ProofVerified._decode(input);
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
      case ProofVerified:
        (value as ProofVerified).encodeTo(output);
        break;
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case ProofVerified:
        return (value as ProofVerified)._sizeHint();
      default:
        throw Exception(
            'Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class ProofVerified extends Event {
  const ProofVerified({required this.exitAmount});

  factory ProofVerified._decode(_i1.Input input) {
    return ProofVerified(exitAmount: _i1.U128Codec.codec.decode(input));
  }

  /// <T as BalancesConfig>::Balance
  final BigInt exitAmount;

  @override
  Map<String, Map<String, BigInt>> toJson() => {
        'ProofVerified': {'exitAmount': exitAmount}
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U128Codec.codec.sizeHint(exitAmount);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i1.U128Codec.codec.encodeTo(
      exitAmount,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ProofVerified && other.exitAmount == exitAmount;

  @override
  int get hashCode => exitAmount.hashCode;
}
