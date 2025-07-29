import 'package:flutter/foundation.dart';

@immutable
class Account {
  final int index; // derivation index
  final String name;
  final String accountId; // address
  final int uiPosition; // UI position
  const Account({
    required this.index,
    required this.name,
    required this.accountId,
    required this.uiPosition,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      index: json['index'] as int,
      name: json['name'] as String,
      accountId: json['accountId'] as String,
      uiPosition: json['uiPosition'] as int? ?? json['index'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'name': name,
      'accountId': accountId,
      'uiPosition': uiPosition,
    };
  }

  Account copyWith({
    int? index,
    String? name,
    String? accountId,
    int? uiPosition,
  }) {
    return Account(
      index: index ?? this.index,
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
      uiPosition: uiPosition ?? this.uiPosition,
    );
  }
}
