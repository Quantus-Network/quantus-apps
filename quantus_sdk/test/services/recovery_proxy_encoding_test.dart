@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/extensions/address_extension.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ss58/ss58.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await RustLib.init();
  });

  group('Recovery proxy account encoding', () {
    test('ss58AddressFromBytes round-trips AccountId32 bytes correctly', () {
      // Generate a keypair and get its account ID address
      final keypair = crypto.generateKeypair(
        mnemonicStr: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      final address = crypto.toAccountId(obj: keypair);

      // Decode the address to get the raw AccountId32 bytes
      final accountIdBytes = crypto.ss58ToAccountId(s: address);

      // Encode using ss58AddressFromBytes (uses Quantus prefix)
      final quantusAddress = AddressExtension.ss58AddressFromBytes(Uint8List.fromList(accountIdBytes));

      // Decode the Quantus address back to bytes using ss58 package (supports any prefix)
      final decodedAddress = Address.decode(quantusAddress);
      final decodedBytes = decodedAddress.pubkey;

      expect(
        decodedBytes,
        equals(accountIdBytes),
        reason: 'ss58AddressFromBytes should round-trip: encoding then decoding should give original bytes',
      );
    });

    test('crypto.toAccountId with AccountId32 bytes as publicKey produces different bytes', () {
      // Generate a keypair and get its correct AccountId32 bytes
      final keypair = crypto.generateKeypair(
        mnemonicStr: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      final correctAddress = crypto.toAccountId(obj: keypair);
      final correctAccountIdBytes = crypto.ss58ToAccountId(s: correctAddress);

      // WRONG: If we use toAccountId with the AccountId32 as publicKey, it will hash again
      final doubleHashedAddress = crypto.toAccountId(
        obj: crypto.Keypair(publicKey: Uint8List.fromList(correctAccountIdBytes), secretKey: Uint8List(0)),
      );

      // Decode to get the bytes - they should NOT match the original AccountId32
      final doubleHashedBytes = crypto.ss58ToAccountId(s: doubleHashedAddress);

      expect(
        doubleHashedBytes,
        isNot(equals(correctAccountIdBytes)),
        reason: 'toAccountId hashes its input, so using AccountId32 as publicKey produces wrong bytes',
      );
    });

    test('ss58AddressFromBytes is the correct way to encode AccountId32 from storage', () {
      final keypair = crypto.generateKeypair(
        mnemonicStr: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );

      // Get the correct AccountId32 bytes (what recovery.proxy storage returns)
      final correctAddress = crypto.toAccountId(obj: keypair);
      final storageReturnedAccountId = crypto.ss58ToAccountId(s: correctAddress);

      // CORRECT: Encode directly without additional hashing
      final correctQuantusAddress = AddressExtension.ss58AddressFromBytes(Uint8List.fromList(storageReturnedAccountId));
      final correctDecodedAddress = Address.decode(correctQuantusAddress);
      final correctAddressBytes = correctDecodedAddress.pubkey;

      // WRONG: What the bug was doing - passing to toAccountId which hashes again
      final wrongAddress = crypto.toAccountId(
        obj: crypto.Keypair(publicKey: Uint8List.fromList(storageReturnedAccountId), secretKey: Uint8List(0)),
      );
      final wrongAddressBytes = crypto.ss58ToAccountId(s: wrongAddress);

      // The correct encoding should preserve the original AccountId32 bytes
      expect(
        correctAddressBytes,
        equals(storageReturnedAccountId),
        reason: 'ss58AddressFromBytes preserves the AccountId32 bytes',
      );

      // The wrong encoding produces different bytes (double-hashed)
      expect(
        wrongAddressBytes,
        isNot(equals(storageReturnedAccountId)),
        reason: 'toAccountId with AccountId32 as publicKey double-hashes and produces wrong bytes',
      );
    });
  });
}
