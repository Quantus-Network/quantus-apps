@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/rust/api/ur.dart';
import 'package:quantus_sdk/src/rust/frb_generated.dart';
import 'package:quantus_sdk/src/utils/ur_qr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  group('isAcceptableUrPart', () {
    test('accepts single-part and multi-part UR frames', () {
      expect(isAcceptableUrPart('ur:bytes/taoeckaemk/...'), isTrue);
      expect(isAcceptableUrPart('ur:bytes/1-5/taoeckaemk/payload'), isTrue);
      expect(isAcceptableUrPart('UR:BYTES/145-256/x/payload'), isTrue);
    });

    test('rejects non-UR payloads', () {
      expect(isAcceptableUrPart('https://www.quantus.com/pay?to=x&amount=1'), isFalse);
      expect(isAcceptableUrPart('urinary:bytes/1-5/x/y'), isFalse);
      expect(isAcceptableUrPart(''), isFalse);
    });

    test('rejects frames longer than a version-40 QR can hold', () {
      expect(isAcceptableUrPart('ur:bytes/${'a' * maxUrPartChars()}'), isFalse);
    });

    test('rejects declared fragment counts beyond the scan cap', () {
      expect(isAcceptableUrPart('ur:bytes/1-${maxUrParts() + 1}/x/y'), isFalse);
      expect(isAcceptableUrPart('ur:bytes/1-${maxUrParts()}/x/y'), isTrue);
      expect(isAcceptableUrPart('ur:bytes/1-0/x/y'), isFalse);
    });

    test('sequence numbers are digit-bounded so int parsing cannot overflow', () {
      // No header match: treated as a single-part payload.
      expect(urSequenceFor('ur:bytes/99999999999999999999-1/x/y'), isNull);
      expect(isAcceptableUrPart('ur:bytes/99999999999999999999-1/x/y'), isTrue);
    });
  });

  group('urSequenceFor', () {
    test('parses the sequence header', () {
      final sequence = urSequenceFor('ur:bytes/3-12/digest/payload');
      expect(sequence, isNotNull);
      expect(sequence!.index, 3);
      expect(sequence.total, 12);
    });

    test('returns null for single-part payloads', () {
      expect(urSequenceFor('ur:bytes/digest/payload'), isNull);
    });
  });
}
