import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:ss58/ss58.dart';

extension AddressExtension on Address {
  // Address is used to convert between ss58 Strings and AccountID32 bytes.
  // The ss58 package assumes Ed25519 addresses, and it assumes that AccountID32 for an ss58 address is
  // the same as the public key.
  // That is not true for dilithium signatures, where AccoundID32 is a
  // Poseidon hash of the public key.
  // Just to explain why this field is named pubkey - it's not a pub key in our signature scheme.
  // However, we can still use this class to convert between ss58 Strings and AccountID32 bytes.
  Uint8List get addressBytes => pubkey;

  static String ss58AddressFromBytes(Uint8List bytes) =>
      Address(prefix: AppConstants.ss58prefix, pubkey: bytes).encode();
}
