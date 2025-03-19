import 'dart:typed_data';
import 'package:polkadart/polkadart.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:polkadart/substrate/era.dart';
import 'package:convert/convert.dart';

enum ResonanceSignatureType {
  ed25519(0),
  sr25519(1),
  ecdsa(2),
  resonance(3);

  final int type;
  const ResonanceSignatureType(this.type);
}

class ResonanceExtrinsicPayload extends ExtrinsicPayload {
  ResonanceExtrinsicPayload({
    required Uint8List signer,
    required Uint8List method,
    required Uint8List signature,
    required int eraPeriod,
    required int blockNumber,
    required int nonce,
    required dynamic tip,
  }) : super(
          signer: signer,
          method: method,
          signature: signature,
          eraPeriod: eraPeriod,
          blockNumber: blockNumber,
          nonce: nonce,
          tip: tip,
        );

  /// Encode the extrinsic payload with all our signature types
  /// This replaces the original method 'encode' in the parent class
  Uint8List encodeResonance(dynamic registry, ResonanceSignatureType signatureType) {
    final ByteOutput output = ByteOutput();

    final int extrinsicVersion = registry.extrinsicVersion;
    // Signed transaction
    final int extraByte = extrinsicVersion | 128;

    output
      ..pushByte(extraByte)
      // 00 = MultiAddress::Id
      ..pushByte(0)
      // Push Signer Address
      ..write(signer)
      // Push signature type byte - 3 for Resonance
      ..pushByte(signatureType.type)
      // Push signature
      ..write(signature);

    // Add signed extensions
    final signedExtensions = registry.getSignedExtensionTypes();
    for (final extension in signedExtensions) {
      switch (extension) {
        case 'CheckMortality':
          if (eraPeriod == 0) {
            output.pushByte(0);
          } else {
            final era = Era.codec.encodeMortal(blockNumber, eraPeriod);
            output.write(Uint8List.fromList(hex.decode(era)));
          }
          break;
        case 'CheckNonce':
          CompactCodec.codec.encodeTo(nonce, output);
          break;
        case 'ChargeTransactionPayment':
          CompactBigIntCodec.codec.encodeTo(tip, output);
          break;
      }
    }

    // Add the method call
    output.write(method);

    return U8SequenceCodec.codec.encode(output.toBytes());
  }
}
