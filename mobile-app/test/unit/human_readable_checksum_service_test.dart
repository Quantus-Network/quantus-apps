import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validAddress = 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda';

  group('HumanReadableChecksumService.getHumanReadableName', () {
    test('returns a checkphrase for a valid address', () async {
      final name = await HumanReadableChecksumService().getHumanReadableName(validAddress);

      expect(name, isNotNull);
      expect(name, isNotEmpty);
      expect(name, contains('-'));
    });

    test('serves repeat lookups from cache', () async {
      final first = await HumanReadableChecksumService().getHumanReadableName(validAddress);
      final second = await HumanReadableChecksumService().getHumanReadableName(validAddress);

      expect(second, first);
    });

    test('is deterministic across addresses', () async {
      final other = await HumanReadableChecksumService().getHumanReadableName(
        'qzjij4Tiow9jtse9d7L1T3NEZuxgFW8JdUbaTLsfgubF7ZQAC',
      );
      final original = await HumanReadableChecksumService().getHumanReadableName(validAddress);

      expect(other, isNotNull);
      expect(other, isNot(original));
    });
  });
}
