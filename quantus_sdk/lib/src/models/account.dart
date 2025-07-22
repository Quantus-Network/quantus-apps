import 'package:flutter/foundation.dart';

@immutable
class Account {
  final int index; // derivation index
  final String name;
  final String accountId; // address
  // balance will be fetched from the chain and not stored here.

  const Account({
    required this.index,
    required this.name,
    required this.accountId,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      index: json['index'] as int,
      name: json['name'] as String,
      accountId: json['accountId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'index': index, 'name': name, 'accountId': accountId};
  }

  Account copyWith({int? index, String? name, String? accountId}) {
    return Account(
      index: index ?? this.index,
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
    );
  }
}
