import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/src/rust/api/crypto.dart';
import 'package:resonance_network_wallet/src/rust/frb_generated.dart';
import 'package:flutter/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  group('Key Generation Tests', () {
    test('should generate correct keypair from known mnemonic phrase', () {
      // This is a valid BIP39 mnemonic phrase - DO NOT use for real wallets
      const testMnemonic =
          'situate more drip void arrest just action prepare engine undo honey delay sponsor come achieve symptom crumble solution glass garden fury valid garbage old';

      // Generate keypair from mnemonic
      final keypair = generateKeypair(mnemonicStr: testMnemonic);

      // Verify keypair was generated
      expect(keypair, isNotNull);
      expect(keypair.publicKey, isNotEmpty);
      expect(keypair.secretKey, isNotEmpty);

      // Convert to account ID
      final accountId = toAccountId(obj: keypair);

      // Verify account ID format (should be a valid SS58 address)
      expect(accountId, isNotEmpty);
      expect(accountId.startsWith('5'), isTrue); // SS58 addresses typically start with '5'

      // Test signing and verification
      final message = [1, 2, 3, 4, 5];
      final signature = signMessage(keypair: keypair, message: message);

      // Verify signature
      expect(signature, isNotEmpty);

      // Verify the signature is valid
      final isValid = verifyMessage(
        keypair: keypair,
        message: message,
        signature: signature,
      );

      expect(isValid, isTrue);
    });

    test('should generate different keypairs for different mnemonics', () {
      // These are valid BIP39 mnemonics - DO NOT use for real wallets
      const mnemonic1 =
          'situate more drip void arrest just action prepare engine undo honey delay sponsor come achieve symptom crumble solution glass garden fury valid garbage old';
      const mnemonic2 =
          'famous laundry soldier gift source below kangaroo scorpion lesson vast welcome grow culture picture chronic sun surge eight cabbage miss hair boss pelican stem';

      final keypair1 = generateKeypair(mnemonicStr: mnemonic1);
      final keypair2 = generateKeypair(mnemonicStr: mnemonic2);

      // Verify different mnemonics generate different keypairs
      expect(keypair1.publicKey, isNot(equals(keypair2.publicKey)));
      expect(keypair1.secretKey, isNot(equals(keypair2.secretKey)));
    });

    test('test for known values', () {
      const mnemonic1 =
          'orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven';

      const known_account_id = '5H72qHthhaHuwybTUZDi9gtVqGbitcYPxUgbid8BLdZyiiMM';

      final keypair = generateKeypair(mnemonicStr: mnemonic1);
      final accountId = toAccountId(obj: keypair);

      expect(accountId, known_account_id);
    });
  });
}
