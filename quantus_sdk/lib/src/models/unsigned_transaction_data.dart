import 'dart:typed_data';

import 'package:quantus_sdk/quantus_sdk.dart';

class UnsignedTransactionData {
  final QuantusSigningPayload payloadToSign;
  final Uint8List signer;
  final dynamic registry;

  Uint8List get encodedPayloadRaw => payloadToSign.encodeRaw(registry);

  Uint8List get encodedPayloadToSign => QuantusSigningPayload.signablePayload(encodedPayloadRaw);

  UnsignedTransactionData({required this.payloadToSign, required this.signer, required this.registry});
}
