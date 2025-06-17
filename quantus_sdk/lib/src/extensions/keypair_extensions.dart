import 'dart:typed_data';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:ss58/ss58.dart';

extension KeypairExtensions on crypto.Keypair {
  String get ss58Address => crypto.toAccountId(obj: this);
  Uint8List get addressBytes => Address.decode(ss58Address).pubkey;
}
