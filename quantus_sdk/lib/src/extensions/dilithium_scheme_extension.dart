import 'package:quantus_sdk/src/rust/api/crypto.dart';

/// Scheme-dependent constants, in one place. Conventions match quantus-cli.
extension DilithiumSchemeExtension on DilithiumScheme {
  /// Scheme new wallets and accounts use.
  static const DilithiumScheme current = DilithiumScheme.mlDsa65;

  /// Scheme of accounts stored before the scheme was recorded.
  static const DilithiumScheme legacy = DilithiumScheme.mlDsa87;

  /// Variant index of the chain's `DilithiumSignatureScheme`, written into every signed extrinsic.
  int get signatureTypeByte => switch (this) {
    DilithiumScheme.mlDsa87 => 0,
    DilithiumScheme.mlDsa65 => 1,
  };

  /// Trailing hardened index of the transparent derivation path (`.../0'` for 87, `.../1'` for 65).
  int get derivationAddressIndex => switch (this) {
    DilithiumScheme.mlDsa87 => 0,
    DilithiumScheme.mlDsa65 => 1,
  };

  /// Name persisted in account storage, same as quantus-cli's `scheme` field.
  String get storageName => switch (this) {
    DilithiumScheme.mlDsa65 => 'ml-dsa-65',
    DilithiumScheme.mlDsa87 => 'ml-dsa-87',
  };

  static DilithiumScheme fromStorageName(String? name) {
    if (name == null) return legacy;
    return DilithiumScheme.values.firstWhere(
      (s) => s.storageName == name,
      orElse: () => throw FormatException('Unknown signature scheme: $name'),
    );
  }

  /// Bytes of an ML-DSA signature. FIPS 204 fixed constants, cross-checked
  /// against the Rust `signatureBytes` in tests.
  int get signatureByteLength => switch (this) {
    DilithiumScheme.mlDsa65 => 3309,
    DilithiumScheme.mlDsa87 => 4627,
  };

  /// Bytes of an ML-DSA public key.
  int get publicKeyByteLength => switch (this) {
    DilithiumScheme.mlDsa65 => 1952,
    DilithiumScheme.mlDsa87 => 2592,
  };

  /// Bytes of `signature ++ publicKey`, the payload every signed extrinsic carries.
  int get signatureWithPublicKeyBytes => signatureByteLength + publicKeyByteLength;

  /// The scheme whose `signature ++ publicKey` is [length] bytes long.
  static DilithiumScheme forSignatureWithPublicKeyLength(int length) => DilithiumScheme.values.firstWhere(
    (s) => s.signatureWithPublicKeyBytes == length,
    orElse: () => throw FormatException('No ML-DSA scheme has a $length-byte signature with public key'),
  );
}
