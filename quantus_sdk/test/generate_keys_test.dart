@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await QuantusSdk.init();
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
      expect(accountId.startsWith('qz'), isTrue); // SS58 addresses typically start with '5'

      // Test signing and verification
      final message = [1, 2, 3, 4, 5];
      final signature = keypair.sign(message);

      // Verify signature
      expect(signature, isNotEmpty);

      // Verify the signature is valid
      final isValid = verifyMessage(keypair: keypair, message: message, signature: signature);

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

      const knownAccountId = 'qzmTAz3UUw1WGUuVh8nbFmPwcftomduwy6twq6NDR6y9qqtEs'; // schroedinger chain spec
      final keypair = generateKeypair(mnemonicStr: mnemonic1);
      final accountId = toAccountId(obj: keypair);

      expect(accountId, knownAccountId);

      // pub const TEST_ADDRESS: &str = "qzmTAz3UUw1WGUuVh8nbFmPwcftomduwy6twq6NDR6y9qqtEs";
      // pub const TEST_ADDRESS_HD_0: &str = "qzm5QCox8Dp5A3oSXZZYHD8YoYgPz7enykZb6RPUropdCyN5h";
      // pub const TEST_ADDRESS_HD_1: &str = "qzmufPopkLKAwDmTzR5uXg8GMp5sUP48CqafJLUz3fPMSSGSh";

      const knownAccountHdIndex0 = 'qzm5QCox8Dp5A3oSXZZYHD8YoYgPz7enykZb6RPUropdCyN5h'; // account index 0
      const knownAccountHdIndex1 = 'qzmufPopkLKAwDmTzR5uXg8GMp5sUP48CqafJLUz3fPMSSGSh'; // account index 1
      final keyPair1 = HdWalletService().keyPairAtIndex(mnemonic1, 0);
      final keyPair2 = HdWalletService().keyPairAtIndex(mnemonic1, 1);
      final accountId1 = toAccountId(obj: keyPair1);
      final accountId2 = toAccountId(obj: keyPair2);
      expect(accountId1, knownAccountHdIndex0);
      expect(accountId2, knownAccountHdIndex1);
    });
    test('wormhole derivation known values', () {
      const mnemonic =
          'orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven';
      const expectedPreimage = 'e4be02a913727c01c1a155fd6e807b7c1a4a13abf37a352b7c9ed4412d127fc3';

      final result = HdWalletService().deriveWormhole(mnemonic);
      expect(hex.encode(result.firstHash), expectedPreimage);

      final addressBytes = ss58ToAccountId(s: result.address);
      final expectedAddressBytes = ss58ToAccountId(s: '5H8AGzwKPtKMfKKuKYCoAFApCoy4EVewCqc9k6GrSgqHoaXm');
      expect(addressBytes, expectedAddressBytes);
    });

    test('test for keystone hardware wallet', () {
      const mnemonic1 = 'human snow truck virus now jaguar wall brisk shoe craft gravity diesel';

      const knownAccountId = 'qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG';
      final keypair = HdWalletService().keyPairAtIndex(mnemonic1, 0);
      final accountId = toAccountId(obj: keypair);
      expect(accountId, knownAccountId);

      // this is a real scale encoded payload.
      const hexPayload =
          '0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e5a77ae1c95817ee664cf733fafa7baa8e6244b396a54e57a5bc414b24c52800600';
      final payload = hex.decode(hexPayload);
      final signature = keypair.sign(payload);
      final isValid = verifyMessage(keypair: keypair, message: payload, signature: signature);
      expect(isValid, true);
      print('signature: ${hex.encode(signature)}');
      final hashedSignature = const Blake2bHasher(32).hash(signature);
      final hashedPayload = const Blake2bHasher(32).hash(Uint8List.fromList(payload));
      print('hashedSignature: ${hex.encode(hashedSignature)}');
      print('hashedPayload: ${hex.encode(hashedPayload)}');
    });

    test('keystone signature UR round-trips and splits into signature + pubkey', () {
      const mnemonic = 'human snow truck virus now jaguar wall brisk shoe craft gravity diesel';
      final keypair = HdWalletService().keyPairAtIndex(mnemonic, 0);

      const hexPayload =
          '0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e5a77ae1c95817ee664cf733fafa7baa8e6244b396a54e57a5bc414b24c52800600';
      final payload = Uint8List.fromList(hex.decode(hexPayload));
      final signable = QuantusSigningPayload.signablePayload(payload);

      // Cold wallet (Keystone) signs the signable payload and emits signature ++ pubkey.
      final signed = signMessageWithPubkey(keypair: keypair, message: signable);

      // The signature QR is a multi-part animated UR (the "5 / 81 frames" case).
      final parts = encodeUr(data: signed);
      expect(parts.length, greaterThan(1));
      expect(isCompleteUr(urParts: parts), isTrue);

      // Hot wallet decodes and splits exactly like KeystoneScanSignatureScreen.
      final bytes = decodeUr(urParts: parts);
      final sigSize = signatureBytes().toInt();
      expect(bytes.length, sigSize + publicKeyBytes().toInt());

      final signature = bytes.sublist(0, sigSize);
      final publicKey = bytes.sublist(sigSize);

      expect(publicKey, equals(keypair.publicKey));
      expect(verifyMessage(keypair: keypair, message: signable, signature: signature), isTrue);
    });
  });
}
