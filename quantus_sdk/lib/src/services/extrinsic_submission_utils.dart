import 'dart:typed_data';

import 'package:polkadart/polkadart.dart';

/// Returns the Blake2b-256 hash of a signed extrinsic payload.
Uint8List localExtrinsicHash(Uint8List extrinsic) {
  return Hasher.blake2b256.hash(extrinsic);
}

/// Whether an RPC error indicates the extrinsic is already in the pool.
///
/// Substrate returns code 1013 ("Already Imported") when the same signed
/// extrinsic is submitted again.
bool isAlreadyImportedError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('1013') || message.contains('already imported') || message.contains('already in pool');
}
