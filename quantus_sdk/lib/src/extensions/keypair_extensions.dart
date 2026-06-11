import 'dart:math';
import 'dart:typed_data';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:ss58/ss58.dart';

extension KeypairExtensions on crypto.Keypair {
  String get ss58Address => crypto.toAccountId(obj: this);
  Uint8List get addressBytes => Address.decode(ss58Address).pubkey;

  /// Hedged (randomized) ML-DSA signature. Fresh entropy is generated per call.
  Uint8List sign(List<int> message) => crypto.signMessage(keypair: this, message: message, entropy: _hedgeEntropy());
}

crypto.U8Array32 _hedgeEntropy() {
  final random = Random.secure();
  return crypto.U8Array32(Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256))));
}
