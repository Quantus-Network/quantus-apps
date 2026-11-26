@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  test('decodes a signature-sized payload read out of order, with repeats and stray codes', () {
    // An ML-DSA-87 signature with its public key, at the cold wallet's default fragment size.
    final data = List<int>.generate(7219, (i) => (i * 7) % 256);
    final parts = encodeUrForQr(data: data, maxFragmentLength: 300);
    expect(parts.length, greaterThan(1));
    final scan = UrScanAccumulator();

    UrScanResult? last;
    for (final part in [...parts.reversed, parts.first, 'not a ur', ...parts]) {
      last = scan.add(part);
      if (last is UrScanComplete) break;
    }

    expect(last, isA<UrScanComplete>().having((c) => c.payload, 'payload', data));
  });
}
