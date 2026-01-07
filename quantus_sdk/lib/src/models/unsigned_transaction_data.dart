import 'dart:typed_data';

import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class UnsignedTransactionData {
  final QuantusSigningPayload payloadToSign;
  final Uint8List signer;
  final dynamic registry;

  Uint8List get encodedPayloadRaw => payloadToSign.encodeRaw(registry);

  Uint8List get encodedPayloadToSign {
    final payloadEncoded = encodedPayloadRaw;
    // print('payloadEncoded Size: ${payloadEncoded.length}');
    // payloadEncoded Size: 119 for a normal transfer - the 256 case may be rare.
    return payloadEncoded.length > 256 ? const Blake2bHasher(32).hash(payloadEncoded) : payloadEncoded;
  }

  UnsignedTransactionData({required this.payloadToSign, required this.signer, required this.registry});
}
