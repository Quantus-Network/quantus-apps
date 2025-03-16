// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  invalidProof('InvalidProof', 0),
  proofDeserializationFailed('ProofDeserializationFailed', 1),
  invalidVerificationKey('InvalidVerificationKey', 2),
  notInitialized('NotInitialized', 3),
  alreadyInitialized('AlreadyInitialized', 4),
  verificationFailed('VerificationFailed', 5),
  verifierNotFound('VerifierNotFound', 6),
  invalidPublicInputs('InvalidPublicInputs', 7),
  nullifierAlreadyUsed('NullifierAlreadyUsed', 8);

  const Error(
    this.variantName,
    this.codecIndex,
  );

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
        return Error.invalidProof;
      case 1:
        return Error.proofDeserializationFailed;
      case 2:
        return Error.invalidVerificationKey;
      case 3:
        return Error.notInitialized;
      case 4:
        return Error.alreadyInitialized;
      case 5:
        return Error.verificationFailed;
      case 6:
        return Error.verifierNotFound;
      case 7:
        return Error.invalidPublicInputs;
      case 8:
        return Error.nullifierAlreadyUsed;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Error value,
    _i1.Output output,
  ) {
    _i1.U8Codec.codec.encodeTo(
      value.codecIndex,
      output,
    );
  }
}
