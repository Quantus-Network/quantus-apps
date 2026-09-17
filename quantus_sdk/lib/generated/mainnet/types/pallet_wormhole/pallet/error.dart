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

  /// The bundle has nothing to settle: only dummy (all-zero) padding, or
  /// every valid segment exits zero. Distinct from [`Error::NullifierAlreadyUsed`],
  /// which is a replay of real segments.
  noValidSegments('NoValidSegments', 2),
  blockNotFound('BlockNotFound', 3),
  verifierNotAvailable('VerifierNotAvailable', 4),
  proofDeserializationFailed('ProofDeserializationFailed', 5),

  /// The submitted proof blob exceeds [`crate::MAX_PROOF_BYTES`]. Rejected before
  /// any copy or parsing so oversized unsigned spam costs only a length check.
  proofTooLarge('ProofTooLarge', 6),

  /// The proof bytes are not the canonical serialization of the decoded proof
  /// (e.g. a valid proof with trailing bytes, which the plonky2 parser would
  /// silently ignore). Every proof has exactly one accepted byte encoding.
  nonCanonicalProofEncoding('NonCanonicalProofEncoding', 7),
  proofVerificationFailed('ProofVerificationFailed', 8),
  invalidProofPublicInputs('InvalidProofPublicInputs', 9),

  /// The volume fee rate in the proof doesn't match the configured rate
  invalidVolumeFeeRate('InvalidVolumeFeeRate', 10),

  /// Only native asset (asset_id = 0) is supported in this version
  nonNativeAssetNotSupported('NonNativeAssetNotSupported', 11);

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
        return Error.proofTooLarge;
      case 7:
        return Error.nonCanonicalProofEncoding;
      case 8:
        return Error.proofVerificationFailed;
      case 9:
        return Error.invalidProofPublicInputs;
      case 10:
        return Error.invalidVolumeFeeRate;
      case 11:
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
