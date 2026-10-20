@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/bell.dart' show Registry;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/rust/frb_generated.dart';

UnsignedTransactionData _unsigned({int specVersion = AppConstants.bundledSpecVersion}) => UnsignedTransactionData(
  payloadToSign: QuantusSigningPayload(
    method: Uint8List.fromList([5, 0, 1, 2, 3]),
    specVersion: specVersion,
    transactionVersion: AppConstants.bundledTransactionVersion,
    genesisHash: '11' * 32,
    blockHash: '22' * 32,
    blockNumber: 42,
    eraPeriod: 16,
    nonce: 0,
    tip: 0,
  ),
  signer: Uint8List(32),
  registry: Registry(),
);

Account _accountFor(Keypair keypair) => Account(
  walletIndex: 0,
  index: 0,
  name: 'Cold',
  accountId: toAccountId(obj: keypair),
  accountType: AccountType.keystone,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Keypair alice;
  late Keypair bob;
  late UnsignedTransactionData unsigned;
  late Uint8List signed;

  setUpAll(() async {
    await RustLib.init();
    alice = crypto.crystalAlice();
    bob = crypto.crystalBob();
    unsigned = _unsigned();
    signed = signMessageWithPubkey(
      keypair: alice,
      message: unsigned.encodedPayloadToSign,
      specVersion: unsigned.payloadToSign.specVersion,
    );
  });

  test('reads the scheme off the length and splits signature from public key', () {
    final response = ColdSignatureResponse.parse(signed);
    expect(response.scheme, DilithiumScheme.mlDsa87);
    expect(response.signature.length, signatureBytes(scheme: DilithiumScheme.mlDsa87));
    expect(response.publicKey, alice.publicKey);
    expect(response.signerAddress, toAccountId(obj: alice));
  });

  test('refuses bytes of no known scheme length', () {
    expect(() => ColdSignatureResponse.parse(Uint8List(100)), throwsA(isA<FormatException>()));
  });

  test('round-trips through UR frames', () {
    final response = ColdSignatureResponse.fromUrParts(encodeUr(data: signed));
    expect(response.bytes, signed);
  });

  test('verifies the signature of the account that was asked to sign', () {
    final response = ColdSignatureResponse.parse(signed);
    expect(response.verifies(unsigned), isTrue);
    response.verifyFor(_accountFor(alice), unsigned);
  });

  test('rejects a signature from another account', () {
    final response = ColdSignatureResponse.parse(signed);
    expect(
      () => response.verifyFor(_accountFor(bob), unsigned),
      throwsA(isA<ColdSignerMismatchException>().having((e) => e.actual, 'actual', toAccountId(obj: alice))),
    );
  });

  test('rejects a tampered signature and a signature under another spec context', () {
    final tampered = Uint8List.fromList(signed);
    tampered[10] ^= 0xff;
    expect(
      () => ColdSignatureResponse.parse(tampered).verifyFor(_accountFor(alice), unsigned),
      throwsA(isA<ColdSignatureInvalidException>()),
    );
    expect(ColdSignatureResponse.parse(signed).verifies(_unsigned(specVersion: 1)), isFalse);
  });
}
