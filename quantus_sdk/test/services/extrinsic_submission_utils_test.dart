import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/extrinsic_submission_utils.dart';

void main() {
  group('isAlreadyImportedError', () {
    test('returns true for Substrate error code 1013', () {
      expect(isAlreadyImportedError(Exception('RPC Error: 1013: Transaction Already Imported')), isTrue);
    });

    test('returns true for already imported message', () {
      expect(isAlreadyImportedError(Exception('Already Imported')), isTrue);
    });

    test('returns true for already in pool message', () {
      expect(isAlreadyImportedError(Exception('Transaction is already in pool')), isTrue);
    });

    test('returns false for unrelated errors', () {
      expect(isAlreadyImportedError(Exception('Connection refused')), isFalse);
      expect(isAlreadyImportedError(Exception('Invalid Transaction')), isFalse);
    });
  });

  group('localExtrinsicHash', () {
    test('returns 32-byte hash for extrinsic bytes', () {
      final extrinsic = Uint8List.fromList([1, 2, 3, 4, 5]);
      final hash = localExtrinsicHash(extrinsic);

      expect(hash, hasLength(32));
      expect(localExtrinsicHash(extrinsic), equals(hash));
    });
  });
}
