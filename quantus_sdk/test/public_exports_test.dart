// Compile-time check that the airdrop API is reachable through the public
// library, without needing the native library loaded.
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  test('airdrop API is exported from quantus_sdk.dart', () {
    expect(findAirdropMatches, isA<Function>());
    expect(buildAirdropDilithiumClaim, isA<Function>());
    expect(proveAirdropWormhole, isA<Function>());
  });
}
