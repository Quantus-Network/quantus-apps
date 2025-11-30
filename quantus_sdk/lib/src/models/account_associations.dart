import 'package:flutter/foundation.dart';

@immutable
class AccountAssociations {
  final String? ethAddress;
  final String? xUsername;

  const AccountAssociations({required this.ethAddress, required this.xUsername});

  factory AccountAssociations.fromJson(Map<String, dynamic> json) {
    return AccountAssociations(
      ethAddress: json['data']['eth_address'] as String?,
      xUsername: json['data']['x_username'] as String?,
    );
  }
}
