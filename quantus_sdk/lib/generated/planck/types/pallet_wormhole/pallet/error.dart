// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  invalidPublicInputs('InvalidPublicInputs', 0),

  /// No segment of the bundle is spendable: every non-dummy segment contains a
  /// nullifier that is already used (or the single segment of a private-batch
  /// proof does).
  nullifierAlreadyUsed('NullifierAlreadyUsed', 1),

  /// The bundle contains only dummy (all-zero) padding segments, so there is
  /// nothing to exit. Distinct from [`Error::NullifierAlreadyUsed`], which is a
  /// replay of real segments.
  noValidSegments('NoValidSegments', 2),
  blockNotFound('BlockNotFound', 3),
  verifierNotAvailable('VerifierNotAvailable', 4),
  proofDeserializationFailed('ProofDeserializationFailed', 5),
  proofVerificationFailed('ProofVerificationFailed', 6),
  invalidProofPublicInputs('InvalidProofPublicInputs', 7),

  /// The volume fee rate in the proof doesn't match the configured rate
  invalidVolumeFeeRate('InvalidVolumeFeeRate', 8),

  /// Transfer amount is below the minimum required
  transferAmountBelowMinimum('TransferAmountBelowMinimum', 9),

  /// Only native asset (asset_id = 0) is supported in this version
  nonNativeAssetNotSupported('NonNativeAssetNotSupported', 10),

  /// Soundness invariant violated: total wormhole exits would exceed the value that could
  /// possibly have been deposited into wormhole addresses. This indicates a potential
  /// soundness bug in the ZK proof system, so the exit is rejected.
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
