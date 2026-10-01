import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/models/signing_request.dart';
import 'package:quantus_sdk/src/quantus_payload_parser.dart';

const signer = 'qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG';
final payload = Uint8List.fromList([0, 0, 1, 2, 3]);

Uint8List envelope(Map<String, Object?> json) => Uint8List.fromList(utf8.encode(jsonEncode(json)));

void main() {
  test('round-trips the signer and the payload', () {
    final decoded = SigningRequest.decode(SigningRequest(signer: signer, payload: payload).encode());

    expect(decoded.signer, signer);
    expect(decoded.payload, payload);
  });

  group('rejects', () {
    test('a bare payload with no envelope', () {
      expect(() => SigningRequest.decode(payload), throwsFormatException);
    });

    test('non-UTF8 bytes', () {
      expect(() => SigningRequest.decode(Uint8List.fromList([0xC3, 0x28])), throwsFormatException);
    });

    test('a JSON value that is not an object', () {
      expect(() => SigningRequest.decode(Uint8List.fromList(utf8.encode('[1,2,3]'))), throwsFormatException);
    });

    test('an unknown version', () {
      expect(
        () => SigningRequest.decode(envelope({'v': 2, 'signer': signer, 'payload': '0x0000'})),
        throwsA(isA<UnsupportedSigningRequestVersionException>().having((e) => e.requested, 'requested', 2)),
      );
    });

    test('a missing key', () {
      expect(() => SigningRequest.decode(envelope({'v': 1, 'signer': signer})), throwsFormatException);
    });

    test('an extra key', () {
      expect(
        () => SigningRequest.decode(envelope({'v': 1, 'signer': signer, 'payload': '0x0000', 'extra': 1})),
        throwsFormatException,
      );
    });

    test('a signer that is not an address', () {
      expect(
        () => SigningRequest.decode(envelope({'v': 1, 'signer': 'not-an-address', 'payload': '0x0000'})),
        throwsFormatException,
      );
    });

    test('a payload that is not 0x hex', () {
      expect(
        () => SigningRequest.decode(envelope({'v': 1, 'signer': signer, 'payload': 'zzzz'})),
        throwsFormatException,
      );
    });

    test('an empty payload', () {
      expect(() => SigningRequest.decode(envelope({'v': 1, 'signer': signer, 'payload': '0x'})), throwsFormatException);
    });

    test('a payload past the cap the parser enforces', () {
      final tooBig = '0x${'00' * (maxPayloadBytes + 1)}';
      expect(
        () => SigningRequest.decode(envelope({'v': 1, 'signer': signer, 'payload': tooBig})),
        throwsFormatException,
      );
    });
  });

  group('NearSigningRequest (version 2)', () {
    final transaction = Uint8List.fromList([0x0d, 0, 0, 0, 0x61]);
    final nearJson = {'v': 2, 'chain': 'near', 'network': 'mainnet', 'payload': '0x0d00000061'};

    test('round-trips the network and the transaction', () {
      final decoded = NearSigningRequest.decode(
        NearSigningRequest(network: 'testnet', transaction: transaction).encode(),
      );

      expect(decoded.network, 'testnet');
      expect(decoded.transaction, transaction);
    });

    test('carries exactly the keys the CLI writes', () {
      final json = jsonDecode(utf8.decode(NearSigningRequest(network: 'mainnet', transaction: transaction).encode()));

      expect(json, nearJson);
    });

    test('is what AnySigningRequest.decode returns for v2, and v1 stays v1', () {
      final near = AnySigningRequest.decode(envelope(nearJson));
      expect(near, isA<NearSigningRequest>().having((r) => r.network, 'network', 'mainnet'));

      final quantus = AnySigningRequest.decode(SigningRequest(signer: signer, payload: payload).encode());
      expect(quantus, isA<SigningRequest>().having((r) => r.signer, 'signer', signer));

      expect(
        () => AnySigningRequest.decode(envelope({'v': 3, 'payload': '0x00'})),
        throwsA(isA<UnsupportedSigningRequestVersionException>().having((e) => e.requested, 'requested', 3)),
      );
      expect(() => AnySigningRequest.decode(payload), throwsFormatException);
    });

    test('rejects another chain, version 1, an empty network, a signer key, a missing key', () {
      expect(() => NearSigningRequest.decode(envelope({...nearJson, 'chain': 'solana'})), throwsFormatException);
      expect(
        () => NearSigningRequest.decode(envelope({...nearJson, 'v': 1})),
        throwsA(isA<UnsupportedSigningRequestVersionException>()),
      );
      expect(() => NearSigningRequest.decode(envelope({...nearJson, 'network': ''})), throwsFormatException);
      expect(() => NearSigningRequest.decode(envelope({...nearJson, 'signer': signer})), throwsFormatException);
      expect(() => NearSigningRequest.decode(envelope({...nearJson}..remove('network'))), throwsFormatException);
      expect(() => NearSigningRequest.decode(envelope({...nearJson, 'payload': '0x'})), throwsFormatException);
      expect(() => NearSigningRequest.decode(envelope({...nearJson, 'payload': 'abcd'})), throwsFormatException);
    });
  });
}
