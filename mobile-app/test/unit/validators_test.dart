import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/utils/validators.dart';

void main() {
  group('Validators', () {
    test('isValidXStatusUrl should validate correct X and Twitter URLs', () {
      final validUrls = [
        'https://x.com/username/status/123456789012345',
        'https://www.x.com/username/status/123456789012345',
        'http://x.com/username/status/123456789012345',
        'https://twitter.com/username/status/123456789012345',
        'https://mobile.twitter.com/username/status/123456789012345',
        'https://mobile.x.com/username/status/123456789012345',
        'https://x.com/username/status/123456789012345?s=20',
        'https://twitter.com/User_Name/status/1234567890',
      ];

      for (final url in validUrls) {
        expect(Validators.isValidXStatusUrl(url), isTrue, reason: 'URL should be valid: $url');
      }
    });

    test('isValidXStatusUrl should reject invalid URLs', () {
      final invalidUrls = [
        'https://google.com',
        'https://x.com/username',
        'https://x.com/status/12345', // Missing username
        'https://x.com/username/12345', // Missing status
        'ftp://x.com/username/status/12345', // Invalid protocol
        'https://other-domain.com/username/status/12345',
        '',
        'random text',
      ];

      for (final url in invalidUrls) {
        expect(Validators.isValidXStatusUrl(url), isFalse, reason: 'URL should be invalid: $url');
      }
    });
  });
}
