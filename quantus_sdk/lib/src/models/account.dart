import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/src/extensions/dilithium_scheme_extension.dart';
import 'package:quantus_sdk/src/extensions/keypair_extensions.dart';
import 'package:quantus_sdk/src/models/base_account.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';

enum AccountType { local, keystone, external, encrypted }

/// How the mnemonic-backed wallet at a given walletIndex came to exist.
/// Absent (legacy wallets) is treated as unknown.
enum WalletOrigin { created, imported }

@immutable
class Account implements BaseAccount {
  final int walletIndex;
  final int index; // derivation index, unique per (walletIndex, scheme)
  @override
  final String name;
  @override
  final String accountId; // address
  final AccountType accountType;

  /// Signature scheme and derivation path of the key behind a local account.
  /// Null for accounts that hold no key here (keystone, encrypted).
  final DilithiumScheme? scheme;
  final String? derivationPath;

  const Account({
    required this.walletIndex,
    required this.index,
    required this.name,
    required this.accountId,
    this.accountType = AccountType.local,
    this.scheme,
    this.derivationPath,
  });

  /// A local account for [keypair], derived at [derivationPath].
  Account.derived({
    required int walletIndex,
    required int index,
    required String name,
    required Keypair keypair,
    required String derivationPath,
  }) : this(
         walletIndex: walletIndex,
         index: index,
         name: name,
         accountId: keypair.ss58Address,
         scheme: keypair.scheme,
         derivationPath: derivationPath,
       );

  /// Local accounts stored before the scheme was recorded are ML-DSA-87 at the legacy path.
  factory Account.fromJson(Map<String, dynamic> json) {
    final accountType = AccountType.values.byName(json['accountType'] as String? ?? AccountType.local.name);
    final index = json['index'] as int;
    final isLocal = accountType == AccountType.local;
    final scheme = isLocal ? DilithiumSchemeExtension.fromStorageName(json['scheme'] as String?) : null;
    return Account(
      walletIndex: (json['walletIndex'] ?? 0) as int,
      index: index,
      name: json['name'] as String,
      accountId: json['accountId'] as String,
      accountType: accountType,
      scheme: scheme,
      derivationPath: isLocal
          ? (json['derivationPath'] as String? ?? HdWalletService.pathForIndex(index, scheme!))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletIndex': walletIndex,
      'index': index,
      'name': name,
      'accountId': accountId,
      'accountType': accountType.name,
      if (scheme != null) 'scheme': scheme!.storageName,
      if (derivationPath != null) 'derivationPath': derivationPath,
    };
  }

  Account copyWith({
    int? walletIndex,
    int? index,
    String? name,
    String? accountId,
    AccountType? accountType,
    DilithiumScheme? scheme,
    String? derivationPath,
  }) {
    return Account(
      walletIndex: walletIndex ?? this.walletIndex,
      index: index ?? this.index,
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
      accountType: accountType ?? this.accountType,
      scheme: scheme ?? this.scheme,
      derivationPath: derivationPath ?? this.derivationPath,
    );
  }

  /// Scheme to size a signed extrinsic's fee and length against when this
  /// account is the sender. Hardware (keystone) accounts hold no local key and
  /// their scheme is only known once the device signs, so the larger ML-DSA-87
  /// is used to avoid ever understating the fee.
  DilithiumScheme get feeSizingScheme => scheme ?? DilithiumSchemeExtension.legacy;

  /// Wallet, then scheme (current first, keyless accounts last), then derivation index.
  static int compare(Account a, Account b) {
    final w = a.walletIndex.compareTo(b.walletIndex);
    if (w != 0) return w;
    final s = _schemeSortOrder(a.scheme).compareTo(_schemeSortOrder(b.scheme));
    return s != 0 ? s : a.index.compareTo(b.index);
  }

  /// Sort position by scheme (current first, legacy next, keyless last). This is
  /// an ordering key, not the derivation path index (which is 0 for 87, 1 for 65).
  static int _schemeSortOrder(DilithiumScheme? scheme) => switch (scheme) {
    DilithiumSchemeExtension.current => 0,
    DilithiumSchemeExtension.legacy => 1,
    null => 2,
  };
}
