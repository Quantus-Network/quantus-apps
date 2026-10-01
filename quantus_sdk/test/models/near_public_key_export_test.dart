import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  const address = 'qzmNaLjPU7hcvkjHpGmrVDPD9y12vdAFimCSrP1GkhVFJMaUq';
  const key = 'ml-dsa-65:3xTqD5Fh2kLm9nPq';

  group('NearPublicKeyExport', () {
    test('encodes to the self-describing JSON a reader dispatches on', () {
      final json = jsonDecode(utf8.decode(const NearPublicKeyExport(address: address, nearPublicKey: key).encode()));
      expect(json, {'v': 1, 'kind': 'near-public-key', 'address': address, 'near_public_key': key});
    });

    test('round-trips', () {
      const export = NearPublicKeyExport(address: address, nearPublicKey: key);
      final decoded = NearPublicKeyExport.decode(export.encode());
      expect(decoded.address, address);
      expect(decoded.nearPublicKey, key);
    });

    test('rejects a wrong version, kind, key prefix, missing or extra key, and non-JSON', () {
      Uint8List bytes(Map<String, Object?> json) => Uint8List.fromList(utf8.encode(jsonEncode(json)));
      const good = {'v': 1, 'kind': 'near-public-key', 'address': address, 'near_public_key': key};
      for (final bad in [
        {...good, 'v': 2},
        {...good, 'kind': 'quantus-public-key'},
        {...good, 'near_public_key': 'ed25519:abc'},
        {...good, 'address': ''},
        {...good}..remove('address'),
        {...good, 'extra': 1},
      ]) {
        expect(() => NearPublicKeyExport.decode(bytes(bad)), throwsFormatException, reason: '$bad');
      }
      expect(() => NearPublicKeyExport.decode(Uint8List.fromList([0xff, 0x00])), throwsFormatException);
      expect(() => NearPublicKeyExport.decode(Uint8List.fromList(utf8.encode('[1]'))), throwsFormatException);
    });
  });
}
