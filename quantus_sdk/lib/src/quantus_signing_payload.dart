import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:polkadart/extrinsic/signed_extensions/signed_extensions_abstract.dart';
import 'package:polkadart/polkadart.dart';
import 'package:polkadart/scale_codec.dart';

class QuantusSigningPayload extends SigningPayload {
  ///
  /// Create a new instance of [SigningPayload]
  ///
  /// For adding assetId or other custom signedExtensions to the payload, use [customSignedExtensions] with key 'assetId' with its mapped value.
  const QuantusSigningPayload({
    required super.method,
    required super.specVersion,
    required super.transactionVersion,
    required super.genesisHash,
    required super.blockHash,
    required super.blockNumber,
    required super.eraPeriod,
    required super.nonce,
    required super.tip,
    super.metadataHash,
    super.customSignedExtensions,
  }) : super();

  /// Substrate rule (unchecked_extrinsic.rs): a signing payload longer than 256
  /// bytes is signed as its Blake2b-256 hash, otherwise it is signed as-is. The
  /// hot wallet, the air-gapped signer, and the chain must all apply this same
  /// rule for a signature to verify, so it lives here as the single source of
  /// truth.
  static Uint8List signablePayload(Uint8List payloadEncoded) =>
      payloadEncoded.length > 256 ? const Blake2bHasher(32).hash(payloadEncoded) : payloadEncoded;

  // This code is 1:1 the same as the original SigningPayload.encode, but we don't hash the result so the HW wallet can parse and display the call correctly.
  // Based on Polkadart v0.7.3 SigningPayload.encode()
  Uint8List encodeRaw(dynamic registry) {
    if (customSignedExtensions.isNotEmpty && registry is! Registry) {
      throw Exception(
        'Custom signed extensions are not supported on this registry. Please use registry from `runtimeMetadata.chainInfo.scaleCodec.registry`.',
      );
    }
    final ByteOutput tempOutput = ByteOutput();

    tempOutput.write(method);

    final ByteOutput output = ByteOutput();

    late final SignedExtensions signedExtensions;
    if (usesChargeAssetTxPayment(registry)) {
      signedExtensions = SignedExtensions.assetHubSignedExtensions;
    } else {
      signedExtensions = SignedExtensions.substrateSignedExtensions;
    }

    final encodedMap = toEncodedMap(registry);

    late List<String> signedExtensionKeys;

    //
    //
    // Do the keys preparation of signedExtensions
    {
      if (registry.getSignedExtensionTypes() is Map) {
        // Usage here for the Registry from the polkadart_scale_codec
        signedExtensionKeys = (registry.getSignedExtensionTypes() as Map<String, Codec<dynamic>>).keys.toList();
      } else {
        // Usage here for the generated lib from the polkadart_cli
        signedExtensionKeys = (registry.getSignedExtensionTypes() as List<dynamic>).cast<String>();
      }
    }

    //
    // Traverse through the signedExtension keys and encode the payload
    for (final extension in signedExtensionKeys) {
      final (payload, found) = signedExtensions.signedExtension(extension, encodedMap);
      if (found) {
        if (payload.isNotEmpty) {
          tempOutput.write(hex.decode(payload));
        }
      } else {
        if (registry.getSignedExtensionTypes() is List) {
          // This method call is from polkadot cli and not from the Reigstry of the polkadart_scale_codec.
          continue;
        }
        // Most probably, it is a custom signed extension.
        // check if this signed extension is NullCodec or not!
        final signedExtensionMap = registry.getSignedExtensionTypes();
        print(signedExtensionMap);
        if (signedExtensionMap[extension] != null &&
            signedExtensionMap[extension] is! NullCodec &&
            signedExtensionMap[extension].hashCode != NullCodec.codec.hashCode) {
          if (customSignedExtensions.containsKey(extension) == false) {
            // throw exception as this is encodable key and we need this key to be present in customSignedExtensions
            throw Exception('Key `$extension` is missing in customSignedExtensions.');
          }
          signedExtensionMap[extension].encodeTo(customSignedExtensions[extension], tempOutput);
        }
      }
    }

    late List<String> additionalSignedExtensionKeys;
    {
      //
      // Do the keys preparation of signedExtensions
      if (registry.getSignedExtensionTypes() is Map) {
        // Usage here for the Registry from the polkadart_scale_codec
        additionalSignedExtensionKeys = (registry.getAdditionalSignedExtensionTypes() as Map<String, Codec<dynamic>>)
            .keys
            .toList();
      } else {
        // Usage here for the generated lib from the polkadart_cli
        additionalSignedExtensionKeys = (registry.getSignedExtensionExtra() as List<dynamic>).cast<String>();
      }
    }

    //
    // Traverse through the additionalSignedExtension keys and encode the payload
    for (final extension in additionalSignedExtensionKeys) {
      final (payload, found) = signedExtensions.additionalSignedExtension(extension, encodedMap);
      if (found) {
        if (payload.isNotEmpty) {
          tempOutput.write(hex.decode(payload));
        }
      } else {
        // Most probably, it is a custom signed extension.
        // check if this signed extension is NullCodec or not!
        if (registry.getSignedExtensionTypes() is List) {
          // This method call is from polkadot cli and not from the Registry of the polkadart_scale_codec.
          continue;
        }
        final additionalSignedExtensionMap = registry.getAdditionalSignedExtensionTypes();
        if (additionalSignedExtensionMap[extension] != null &&
            additionalSignedExtensionMap[extension] is! NullCodec &&
            additionalSignedExtensionMap[extension].hashCode != NullCodec.codec.hashCode) {
          if (customSignedExtensions.containsKey(extension) == false) {
            // throw exception as this is encodable key and we need this key to be present in customSignedExtensions
            throw Exception('Key `$extension` is missing in customSignedExtensions.');
          }
          additionalSignedExtensionMap[extension].encodeTo(customSignedExtensions[extension], tempOutput);
        }
      }
    }

    output.write(tempOutput.toBytes());
    final payloadEncoded = output.toBytes();

    // This is the only difference between the original SigningPayload and the QuantusSigningPayload.encodeRaw.
    // We don't hash the result so the HW wallet can parse and display the call correctly.
    return payloadEncoded;
    // See rust code: https://github.com/paritytech/polkadot-sdk/blob/e349fc9ef8354eea1bafc1040c20d6fe3189e1ec/substrate/primitives/runtime/src/generic/unchecked_extrinsic.rs#L253
    // return payloadEncoded.length > 256 ? Blake2bHasher(32).hash(payloadEncoded) : payloadEncoded;
  }
}
