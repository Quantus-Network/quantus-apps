// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  invalidPublicInputs('InvalidPublicInputs', 0),
  nullifierAlreadyUsed('NullifierAlreadyUsed', 1),
  noValidSegments('NoValidSegments', 2),
  blockNotFound('BlockNotFound', 3),
  verifierNotAvailable('VerifierNotAvailable', 4),
  proofDeserializationFailed('ProofDeserializationFailed', 5),
  proofVerificationFailed('ProofVerificationFailed', 6),
  invalidProofPublicInputs('InvalidProofPublicInputs', 7),
  invalidVolumeFeeRate('InvalidVolumeFeeRate', 8),
  transferAmountBelowMinimum('TransferAmountBelowMinimum', 9),
  nonNativeAssetNotSupported('NonNativeAssetNotSupported', 10),
  soundnessInvariantViolation('SoundnessInvariantViolation', 11);

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
        return Error.noValidSegments;
      case 3:
        return Error.blockNotFound;
      case 4:
        return Error.verifierNotAvailable;
      case 5:
        return Error.proofDeserializationFailed;
      case 6:
        return Error.proofVerificationFailed;
      case 7:
        return Error.invalidProofPublicInputs;
      case 8:
        return Error.invalidVolumeFeeRate;
      case 9:
        return Error.transferAmountBelowMinimum;
      case 10:
        return Error.nonNativeAssetNotSupported;
      case 11:
        return Error.soundnessInvariantViolation;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Error value, _i1.Output output) {
    _i1.U8Codec.codec.encodeTo(value.codecIndex, output);
  }
}
