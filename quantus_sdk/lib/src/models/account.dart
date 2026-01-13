import 'package:flutter/foundation.dart';

enum AccountType { local, keystone, external }

@immutable
class Account {
  final int walletIndex;
  final int index; // derivation index
  final String name;
  final String accountId; // address
  final AccountType accountType;
  const Account({
    required this.walletIndex,
    required this.index,
    required this.name,
    required this.accountId,
    this.accountType = AccountType.local,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      walletIndex: (json['walletIndex'] ?? 0) as int,
      index: json['index'] as int,
      name: json['name'] as String,
      accountId: json['accountId'] as String,
      accountType: AccountType.values.byName(json['accountType'] as String? ?? AccountType.local.name),
    );
  }

  factory Account.fromSs58Address(String ss58Address) {
    return Account(
      walletIndex: -1,
      index: -2,
      accountId: ss58Address,
      name: 'External Account',
      accountType: AccountType.external,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletIndex': walletIndex,
      'index': index,
      'name': name,
      'accountId': accountId,
      'accountType': accountType.name,
    };
  }

  Account copyWith({int? walletIndex, int? index, String? name, String? accountId, AccountType? accountType}) {
    return Account(
      walletIndex: walletIndex ?? this.walletIndex,
      index: index ?? this.index,
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
      accountType: accountType ?? this.accountType,
    );
  }
}
