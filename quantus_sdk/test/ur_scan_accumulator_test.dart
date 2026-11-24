import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Stand-ins for the Rust UR checks, which these tests cannot load: a frame
/// is acceptable when it starts with `ur:`, and [parts] frames are complete
/// once every one of them has been seen.
class _Ur {
  _Ur({this.parts = 3});

  final int parts;

  /// What each decode was given.
  final decoded = <List<String>>[];

  /// When set, decoding throws this.
  Object? decodeError;

  UrScanAccumulator accumulator({int maxParts = 256}) => UrScanAccumulator(
    isAcceptable: (part) => part.startsWith('ur:'),
    isComplete: (seen) => seen.length >= parts,
    decode: (seen) {
      decoded.add(seen);
      final error = decodeError;
      if (error != null) throw error;
      return Uint8List.fromList([seen.length]);
    },
    maxParts: maxParts,
  );

  String frame(int index) => 'ur:bytes/$index-$parts/frame$index';
}

void main() {
  test('ignores a code the acceptance check refuses', () {
    final scan = _Ur().accumulator();

    expect(scan.add('https://example.com'), isA<UrScanIgnored>());
    expect(scan.scanned, 0);
  });

  test('counts a repeated frame once', () {
    final ur = _Ur();
    final scan = ur.accumulator();

    expect(scan.add(ur.frame(1)), isA<UrScanProgress>());
    expect(scan.add(ur.frame(1)), isA<UrScanIgnored>());
    expect(scan.scanned, 1);
  });

  test('reports the frames scanned and the total the sequence declares', () {
    final ur = _Ur();
    final scan = ur.accumulator();

    expect(scan.total, isNull);
    final progress = scan.add(ur.frame(2));

    expect(progress, isA<UrScanProgress>().having((p) => p.scanned, 'scanned', 1).having((p) => p.total, 'total', 3));
    expect((scan.scanned, scan.total), (1, 3));
  });

  test('completes with the decoded bytes once the frames make up the payload, in any order', () {
    final ur = _Ur();
    final scan = ur.accumulator();

    scan.add(ur.frame(3));
    scan.add(ur.frame(1));
    final result = scan.add(ur.frame(2));

    expect(result, isA<UrScanComplete>().having((c) => c.payload, 'payload', [3]));
    expect(ur.decoded.single, unorderedEquals([ur.frame(1), ur.frame(2), ur.frame(3)]));
  });

  test('ignores frames once complete, until reset', () {
    final ur = _Ur(parts: 1);
    final scan = ur.accumulator();

    expect(scan.add(ur.frame(1)), isA<UrScanComplete>());
    expect(scan.add('ur:bytes/other'), isA<UrScanIgnored>());
    expect(ur.decoded, hasLength(1));

    scan.reset();
    expect(scan.add(ur.frame(1)), isA<UrScanComplete>());
  });

  test('reports an overflow at the frame limit without completing, and starts over', () {
    final ur = _Ur(parts: 10);
    final scan = ur.accumulator(maxParts: 2);

    scan.add(ur.frame(1));
    scan.add(ur.frame(2));
    expect(scan.add(ur.frame(3)), isA<UrScanOverflow>());
    expect((scan.scanned, scan.total), (0, null));

    expect(scan.add(ur.frame(1)), isA<UrScanProgress>());
  });

  test('reports a failed decode and starts over', () {
    final ur = _Ur(parts: 1)..decodeError = const FormatException('bad');
    final scan = ur.accumulator();

    expect(scan.add(ur.frame(1)), isA<UrScanFailed>().having((f) => f.error, 'error', isA<FormatException>()));
    expect(scan.scanned, 0);

    ur.decodeError = null;
    expect(scan.add(ur.frame(1)), isA<UrScanComplete>());
  });

  test('reset clears the frames scanned', () {
    final ur = _Ur();
    final scan = ur.accumulator();
    scan.add(ur.frame(1));

    scan.reset();

    expect((scan.scanned, scan.total), (0, null));
    expect(scan.add(ur.frame(1)), isA<UrScanProgress>());
  });
}
