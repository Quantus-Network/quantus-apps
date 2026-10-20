import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  group('ColdSignRequestKey', () {
    test('trims the recipient in fromSendParams', () {
      final key = ColdSignRequestKey.fromSendParams(
        accountId: 'account-a',
        recipientAddress: '  recipient  ',
        amount: BigInt.from(100),
      );
      expect(key.recipientAddress, 'recipient');
    });

    test('equal keys match regardless of recipient whitespace', () {
      final a = ColdSignRequestKey.fromSendParams(accountId: 'a', recipientAddress: 'r', amount: BigInt.one);
      final b = ColdSignRequestKey.fromSendParams(accountId: 'a', recipientAddress: ' r ', amount: BigInt.one);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('forExtrinsic keys distinguish by identity', () {
      final approve = ColdSignRequestKey.forExtrinsic(accountId: 'a', identity: 'approve|msig|1');
      final execute = ColdSignRequestKey.forExtrinsic(accountId: 'a', identity: 'execute|msig|1');
      expect(approve, ColdSignRequestKey.forExtrinsic(accountId: 'a', identity: 'approve|msig|1'));
      expect(approve, isNot(execute));
    });
  });

  group('requestBytes', () {
    final payload = Uint8List.fromList(List.generate(64, (i) => i));
    const signer = AppConstants.debugTestAddress;

    test('addresses the payload to the account that must sign it', () {
      final decoded = SigningRequest.decode(ColdSignRequest.requestBytes(signer: signer, payload: payload));
      expect(decoded.signer, signer);
      expect(decoded.payload, payload);
    });

    test('is not the bare payload, which the signer refuses', () {
      expect(() => SigningRequest.decode(payload), throwsA(isA<FormatException>()));
    });
  });
}
