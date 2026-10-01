import 'dart:math';
import 'dart:typed_data';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
import 'package:quantus_sdk/src/rust/api/near.dart' as near;
import 'package:quantus_sdk/src/rust/lib.dart' show U8Array32;
import 'package:ss58/ss58.dart';

extension KeypairExtensions on crypto.Keypair {
  String get ss58Address => crypto.toAccountId(obj: this);
  Uint8List get addressBytes => Address.decode(ss58Address).pubkey;

  /// Hedged ML-DSA signature. [specVersion] 148+ uses QUANTUS_EXTRINSIC; earlier specs use none.
  Uint8List sign(List<int> message, {required int specVersion}) =>
      crypto.signMessage(keypair: this, message: message, entropy: _hedgeEntropy(), specVersion: specVersion);

  /// Hedged pure ML-DSA-65 signature over a borsh NEAR `TransactionV0`.
  /// Returns `signature ‖ public_key`, the cold-signing response NEAR tooling expects.
  Uint8List signNear(List<int> transaction) =>
      near.signNearTransaction(keypair: this, transaction: transaction, entropy: _hedgeEntropy());
}

U8Array32 _hedgeEntropy() {
  final random = Random.secure();
  return U8Array32(Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256))));
}
