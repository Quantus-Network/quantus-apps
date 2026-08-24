@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
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
      expect(isAcceptableUrPart('ur:bytes/${'a' * maxUrScanPartChars}'), isFalse);
    });

    test('rejects declared fragment counts beyond the scan cap', () {
      expect(isAcceptableUrPart('ur:bytes/1-${maxUrScanParts + 1}/x/y'), isFalse);
      expect(isAcceptableUrPart('ur:bytes/1-$maxUrScanParts/x/y'), isTrue);
      expect(isAcceptableUrPart('ur:bytes/1-0/x/y'), isFalse);
    });

    test('rejects an index outside its own declared count, as the decoder does', () {
      expect(isAcceptableUrPart('ur:bytes/6-5/x/y'), isFalse);
      expect(isAcceptableUrPart('ur:bytes/0-5/x/y'), isFalse);
      expect(isAcceptableUrPart('ur:bytes/5-5/x/y'), isTrue);
    });

    test('rejects out-of-range sequence headers instead of reading them as single-part', () {
      // A header the int parser cannot hold must fail closed — treating it as a
      // header-less frame would let any count past the cap.
      expect(urSequenceFor('ur:bytes/99999999999999999999-1/x/y'), isNull);
      expect(isAcceptableUrPart('ur:bytes/99999999999999999999-1/x/y'), isFalse);
      expect(isAcceptableUrPart('ur:bytes/1-1000000/x/y'), isFalse);
      expect(isAcceptableUrPart('ur:bytes/1234567-1/x/y'), isFalse);
    });

    test('the sequence header is only read from the frame head', () {
      // An unanchored pattern would find "/1-2/" anywhere in the payload.
      expect(urSequenceFor('ur:bytes/digest/payload/1-2/more'), isNull);
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
