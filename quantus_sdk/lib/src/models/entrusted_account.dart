import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/src/models/base_account.dart';

@immutable
class EntrustedAccount implements BaseAccount {
  final String parentAccountId;
  final int index; // derivation index
  @override
  final String name;
  @override
  final String accountId; // address
  const EntrustedAccount({
    required this.parentAccountId,
    required this.index,
    required this.name,
    required this.accountId,
  });

  factory EntrustedAccount.fromJson(Map<String, dynamic> json) {
    return EntrustedAccount(
      parentAccountId: json['parentAccountId'] as String,
      index: json['index'] as int,
      name: json['name'] as String,
      accountId: json['accountId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'parentAccountId': parentAccountId, 'index': index, 'name': name, 'accountId': accountId};
  }
}
