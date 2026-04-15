// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i3;

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

  Map<String, Map<String, List<int>>> toJson();
}

class $Call {
  const $Call();

  VerifyAggregatedProof verifyAggregatedProof({required List<int> proofBytes}) {
    return VerifyAggregatedProof(proofBytes: proofBytes);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 2:
        return VerifyAggregatedProof._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Call value, _i1.Output output) {
    switch (value.runtimeType) {
      case VerifyAggregatedProof:
        (value as VerifyAggregatedProof).encodeTo(output);
        break;
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case VerifyAggregatedProof:
        return (value as VerifyAggregatedProof)._sizeHint();
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Verify an aggregated wormhole proof and process all transfers in the batch.
///
/// Returns `DispatchResultWithPostInfo` to allow weight correction on early failures.
/// If validation fails before ZK verification, we return minimal weight.
/// If ZK verification fails, we return full weight since the work was done.
class VerifyAggregatedProof extends Call {
  const VerifyAggregatedProof({required this.proofBytes});

  factory VerifyAggregatedProof._decode(_i1.Input input) {
    return VerifyAggregatedProof(proofBytes: _i1.U8SequenceCodec.codec.decode(input));
  }

  /// Vec<u8>
  final List<int> proofBytes;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'verify_aggregated_proof': {'proofBytes': proofBytes},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U8SequenceCodec.codec.sizeHint(proofBytes);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    _i1.U8SequenceCodec.codec.encodeTo(proofBytes, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VerifyAggregatedProof && _i3.listsEqual(other.proofBytes, proofBytes);

  @override
  int get hashCode => proofBytes.hashCode;
}
