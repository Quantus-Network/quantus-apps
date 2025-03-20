import 'dart:typed_data';
import 'package:polkadart/extrinsic/signed_extensions/signed_extensions_abstract.dart';
import 'package:polkadart/polkadart.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:polkadart/substrate/era.dart';
import 'package:convert/convert.dart';

/// This is a modified version of the ExtrinsicPayload class from polkadart
/// It adds a method to encode the extrinsic payload with all our signature types
/// This replaces the original method 'encode' in the parent class
///
/// The reason we need this is that vanilla polkadart is not using the chain metadata to encode
/// the signature type. Instead, it is redefining the original sig type.

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
    required super.signer,
    required super.method,
    required super.signature,
    required super.eraPeriod,
    required super.blockNumber,
    required super.nonce,
    required super.tip,
  });

  @override
  Map<String, dynamic> toEncodedMap(dynamic registry) {
    return {
      'signer': signer,
      'method': method,
      'signature': signature,
      'era': eraPeriod == 0 ? '00' : Era.codec.encodeMortal(blockNumber, eraPeriod),
      'nonce': encodeHex(CompactCodec.codec.encode(nonce)),
      /* 'assetId': maybeAssetIdEncoded(registry), */
      'tip': tip is int ? encodeHex(CompactCodec.codec.encode(tip)) : encodeHex(CompactBigIntCodec.codec.encode(tip)),
      // This is for the `CheckMetadataHash` signed extension.
      // it sets the mode byte to true if a metadataHash is present.
      'mode': metadataHash == '00' ? '00' : '01',
      // This is for the `CheckMetadataHash` additional signed extensions.
      // we sign the `Option<MetadataHash>::None` by setting it to '00'.
      'metadataHash': metadataHash == '00' ? '00' : '01${metadataHash.replaceAll('0x', '')}',
    };
  }

  /// Encode the extrinsic payload with all our signature types
  /// This replaces the original method 'encode' in the parent class
  // Uint8List encodeResonance(dynamic registry, ResonanceSignatureType signatureType) {

  Uint8List encodeResonance(dynamic registry, ResonanceSignatureType signatureType) {
    if (customSignedExtensions.isNotEmpty && registry is! Registry) {
      throw Exception(
          'Custom signed extensions are not supported on this registry. Please use registry from `runtimeMetadata.chainInfo.scaleCodec.registry`.');
    }
    final ByteOutput output = ByteOutput();

    final int extrinsicVersion = registry.extrinsicVersion;
    // Unsigned transaction
    final int preByte = extrinsicVersion & 127;
    // ignore: unused_local_variable
    final String inHex = preByte.toRadixString(16);

    // Signed transaction
    final int extraByte = extrinsicVersion | 128;

    output
      ..pushByte(extraByte)
      // 00 = MultiAddress::Id
      ..pushByte(0)
      // Push Signer Address
      ..write(signer)
      // Push signature type byte
      ..pushByte(signatureType.type)
      // Push signature
      ..write(signature);

    late final SignedExtensions signedExtensions;

    final encodedMap = toEncodedMap(registry);

    if (usesChargeAssetTxPayment(registry)) {
      signedExtensions = SignedExtensions.assetHubSignedExtensions;
    } else {
      signedExtensions = SignedExtensions.substrateSignedExtensions;
    }

    late List<String> keys;
    {
      //
      //
      // Prepare keys for the encoding
      if (registry.getSignedExtensionTypes() is Map) {
        keys = (registry.getSignedExtensionTypes() as Map<String, Codec<dynamic>>).keys.toList();
      } else {
        keys = (registry.getSignedExtensionTypes() as List<dynamic>).cast<String>();
      }
    }

    for (final extension in keys) {
      final (payload, found) = signedExtensions.signedExtension(extension, encodedMap);
      if (found) {
        if (payload.isNotEmpty) {
          output.write(hex.decode(payload));
        }
      } else {
        if (registry.getSignedExtensionTypes() is List) {
          // This method call is from polkadot cli and not from the Reigstry of the polkadart_scale_codec.
          continue;
        }
        // Most probably, it is a custom signed extension.
        final signedExtensionMap = registry.getSignedExtensionTypes();

        // check if this signed extension is NullCodec or not!
        if (signedExtensionMap[extension] != null &&
            signedExtensionMap[extension] is! NullCodec &&
            signedExtensionMap[extension].hashCode != NullCodec.codec.hashCode) {
          if (customSignedExtensions.containsKey(extension) == false) {
            // throw exception as this is encodable key and we need this key to be present in customSignedExtensions
            throw Exception('Key `$extension` is missing in customSignedExtensions.');
          }
          signedExtensionMap[extension].encodeTo(customSignedExtensions[extension], output);
        }
      }
    }

    // Add the method call -> transfer.....
    output.write(method);

    return U8SequenceCodec.codec.encode(output.toBytes());
  }
}
