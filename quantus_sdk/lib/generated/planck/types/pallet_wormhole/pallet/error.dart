// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  invalidPublicInputs('InvalidPublicInputs', 0),
  nullifierAlreadyUsed('NullifierAlreadyUsed', 1),
  blockNotFound('BlockNotFound', 2),
  aggregatedVerifierNotAvailable('AggregatedVerifierNotAvailable', 3),
  aggregatedProofDeserializationFailed('AggregatedProofDeserializationFailed', 4),
  aggregatedVerificationFailed('AggregatedVerificationFailed', 5),
  invalidAggregatedPublicInputs('InvalidAggregatedPublicInputs', 6),

  /// The volume fee rate in the proof doesn't match the configured rate
  invalidVolumeFeeRate('InvalidVolumeFeeRate', 7),

  /// Transfer amount is below the minimum required
  transferAmountBelowMinimum('TransferAmountBelowMinimum', 8),

  /// Only native asset (asset_id = 0) is supported in this version
  nonNativeAssetNotSupported('NonNativeAssetNotSupported', 9);

  const Error(this.variantName, this.codecIndex);

  factory Error.decode(_i1.Input input) {
    return codec.decode(input);
  }

  final String variantName;

  final int codecIndex;

  static const $ErrorCodec codec = $ErrorCodec();

  String toJson() => variantName;

  _i2.Uint8List encode() {
    return codec.encode(this);
  }
}

class $ErrorCodec with _i1.Codec<Error> {
  const $ErrorCodec();

  @override
  Error decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Error.invalidPublicInputs;
      case 1:
        return Error.nullifierAlreadyUsed;
      case 2:
        return Error.blockNotFound;
      case 3:
        return Error.aggregatedVerifierNotAvailable;
      case 4:
        return Error.aggregatedProofDeserializationFailed;
      case 5:
        return Error.aggregatedVerificationFailed;
      case 6:
        return Error.invalidAggregatedPublicInputs;
      case 7:
        return Error.invalidVolumeFeeRate;
      case 8:
        return Error.transferAmountBelowMinimum;
      case 9:
        return Error.nonNativeAssetNotSupported;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Error value, _i1.Output output) {
    _i1.U8Codec.codec.encodeTo(value.codecIndex, output);
  }
}
