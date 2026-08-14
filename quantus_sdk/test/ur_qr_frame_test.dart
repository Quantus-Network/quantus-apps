@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  // Regression: the ML-DSA signature-plus-public-key payload (7,219 bytes) at
  // large fragment settings used to produce UR frames longer than a version-40
  // QR can hold, throwing QrInputTooLongException after signing.
  test('signature payload fits QR frames at every fragment setting', () {
    final payloadSize = (signatureBytes() + publicKeyBytes()).toInt();
    expect(payloadSize, 7219);
    final data = List<int>.generate(payloadSize, (i) => i % 256);

    for (var fragment = 300; fragment <= 1500; fragment += 25) {
      final parts = encodeUrForQr(data: data, maxFragmentLength: fragment);
      var longest = '';
      for (final part in parts) {
        expect(part.length, lessThanOrEqualTo(maxUrQrFrameChars), reason: 'fragment setting $fragment');
        if (part.length > longest.length) longest = part;
      }
      QrCode.fromData(data: longest, errorCorrectLevel: QrErrorCorrectLevel.L);
      expect(decodeUr(urParts: parts), equals(data), reason: 'fragment setting $fragment');
    }
  });
}
