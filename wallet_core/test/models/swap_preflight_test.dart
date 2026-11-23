import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_core/models/swap_preflight.dart';

void main() {
  group('checkSwapPreflightDefines', () {
    test('a build with no stand-in starts, debug or not', () {
      checkSwapPreflightDefines(assetId: '', address: '', isDebugBuild: false);
      checkSwapPreflightDefines(assetId: '', address: '', isDebugBuild: true);
    });

    test('a stand-in outside a debug build stops the start: real builds swap QTC only', () {
      expect(
        () => checkSwapPreflightDefines(assetId: 'nep141:usdc', address: '0xTester', isDebugBuild: false),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('debug builds only'))),
      );
    });

    test('a stand-in with no address to take the account\'s place stops the start', () {
      expect(
        () => checkSwapPreflightDefines(assetId: 'nep141:usdc', address: '', isDebugBuild: true),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('SWAP_PREFLIGHT_ADDRESS'))),
      );
    });

    test('a debug build with a stand-in and its address starts', () {
      checkSwapPreflightDefines(assetId: 'nep141:usdc', address: '0xTester', isDebugBuild: true);
    });
  });
}
