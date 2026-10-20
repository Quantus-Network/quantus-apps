import 'dart:typed_data';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:quantus_sdk/src/extensions/dilithium_scheme_extension.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/unsigned_transaction_data.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart';
import 'package:quantus_sdk/src/rust/api/ur.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';
import 'package:quantus_sdk/src/signing/cold_sign_era.dart';

class ColdSignerMismatchException implements Exception {
  final String expected;
  final String actual;

  const ColdSignerMismatchException({required this.expected, required this.actual});

  @override
  String toString() => 'Signature is from $actual, not from $expected';
}

class ColdSignatureInvalidException implements Exception {
  final String message;

  const ColdSignatureInvalidException(this.message);

  @override
  String toString() => 'Invalid signature: $message';
}

/// What an air-gapped signer sends back: `signature ‖ publicKey`, with the
/// scheme read off the length. The hot side checks that the key belongs to the
/// account it asked to sign and that the signature verifies before broadcasting.
class ColdSignatureResponse {
  final Uint8List bytes;
  final DilithiumScheme scheme;

  const ColdSignatureResponse._(this.bytes, this.scheme);

  factory ColdSignatureResponse.parse(Uint8List bytes) =>
      ColdSignatureResponse._(bytes, DilithiumSchemeExtension.forSignatureWithPublicKeyLength(bytes.length));

  factory ColdSignatureResponse.fromUrParts(List<String> parts) =>
      ColdSignatureResponse.parse(decodeUr(urParts: parts));

  int get _signatureLength => signatureBytes(scheme: scheme);

  Uint8List get signature => Uint8List.sublistView(bytes, 0, _signatureLength);

  Uint8List get publicKey => Uint8List.sublistView(bytes, _signatureLength);

  Keypair get _publicKeypair => Keypair(publicKey: publicKey, secretKey: Uint8List(0), scheme: scheme);

  String get signerAddress => toAccountId(obj: _publicKeypair);

  bool verifies(UnsignedTransactionData unsigned) {
    try {
      return verifyMessage(
        keypair: _publicKeypair,
        message: unsigned.encodedPayloadToSign,
        signature: signature,
        specVersion: unsigned.payloadToSign.specVersion,
      );
    } on PanicException catch (e) {
      throw ColdSignatureInvalidException('$e');
    }
  }

  void verifyFor(Account account, UnsignedTransactionData unsigned) {
    final signer = signerAddress;
    if (signer != account.accountId) throw ColdSignerMismatchException(expected: account.accountId, actual: signer);
    if (!verifies(unsigned)) throw ColdSignatureInvalidException('does not verify for ${account.accountId}');
  }
}

/// Era check, signer and signature verification, then broadcast. Returns the extrinsic hash bytes.
Future<Uint8List> submitColdSigned({
  required Account account,
  required UnsignedTransactionData unsigned,
  required ColdSignatureResponse response,
  SubstrateService? substrate,
}) async {
  final service = substrate ?? SubstrateService();
  ColdSignEra.ensureNotExpired(unsigned.payloadToSign, await service.getCurrentBlockNumber());
  response.verifyFor(account, unsigned);
  return service.submitExtrinsicWithExternalSignature(unsigned, response.bytes);
}
