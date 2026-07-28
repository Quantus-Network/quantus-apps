import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

// The checkphrase wordlist asset is bundled with the apps, not with
// quantus_sdk, so loading it here fails — which exercises the failure path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HumanReadableChecksumService.getHumanReadableName failure handling', () {
    test('returns null instead of throwing or an empty string when initialization fails', () async {
      final name = await HumanReadableChecksumService().getHumanReadableName(
        'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda',
      );

      expect(name, isNull);
    });
  });
}
