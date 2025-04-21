import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/src/rust/api/crypto.dart' as crypto;
import 'package:resonance_network_wallet/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

void main() {
  setUpAll(() async {
    try {
      await RustLib.init(
        externalLibrary: ExternalLibrary.open('rust/target/debug/librust_lib_resonance_network_wallet.dylib'),
      );
    } catch (e) {
      print('Error initializing Rust library: $e');
      rethrow;
    }
  });

  test('Crystal Alice account ID matches expected value', () {
    final keypair = crypto.crystalAlice();
    final accountId = crypto.toAccountId(obj: keypair);

    print('Crystal Alice public key: ${keypair.publicKey}');
    print('Crystal Alice account ID: $accountId');

    expect(accountId, equals('5H7DdvKue19FQZpRKc2hmBfSBGEczwvdnVYDNZC3W95UDyGP'));
  });
}
