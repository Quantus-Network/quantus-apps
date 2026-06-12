import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/src/models/base_account.dart';

@immutable
class MultisigAccount implements BaseAccount {
  @override
  final String name;
  @override
  final String accountId;
  final List<String> signers;
  final int threshold;
  final BigInt nonce;
  final String myMemberAccountId;
  final String? creator;

  const MultisigAccount({
    required this.name,
    required this.accountId,
    required this.signers,
    required this.threshold,
    required this.nonce,
    required this.myMemberAccountId,
    this.creator,
  });

  factory MultisigAccount.fromJson(Map<String, dynamic> json) {
    return MultisigAccount(
      name: json['name'] as String,
      accountId: json['accountId'] as String,
      signers: (json['signers'] as List<dynamic>).cast<String>(),
      threshold: json['threshold'] as int,
      nonce: BigInt.parse(json['nonce'] as String),
      myMemberAccountId: json['myMemberAccountId'] as String,
      creator: json['creator'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'accountId': accountId,
      'signers': signers,
      'threshold': threshold,
      'nonce': nonce.toString(),
      'myMemberAccountId': myMemberAccountId,
      'creator': creator,
    };
  }

  MultisigAccount copyWith({
    String? name,
    String? accountId,
    List<String>? signers,
    int? threshold,
    BigInt? nonce,
    String? myMemberAccountId,
    String? creator,
  }) {
    return MultisigAccount(
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
      signers: signers ?? this.signers,
      threshold: threshold ?? this.threshold,
      nonce: nonce ?? this.nonce,
      myMemberAccountId: myMemberAccountId ?? this.myMemberAccountId,
      creator: creator ?? this.creator,
    );
  }
}
