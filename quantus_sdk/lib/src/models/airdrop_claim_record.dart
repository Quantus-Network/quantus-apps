import 'package:flutter/foundation.dart';

/// What a wallet's testnet mining rewards claim was submitted as, kept so the
/// flow can show it again instead of re-checking.
@immutable
class AirdropClaimRecord {
  final DateTime claimedAt;
  final int rewardHundredths;
  final String claimAccount;

  /// Name of the user's own account when the payout goes to one.
  final String? accountName;

  const AirdropClaimRecord({
    required this.claimedAt,
    required this.rewardHundredths,
    required this.claimAccount,
    this.accountName,
  });

  factory AirdropClaimRecord.fromJson(Map<String, dynamic> json) => AirdropClaimRecord(
    claimedAt: DateTime.parse(json['claimedAt'] as String),
    rewardHundredths: json['rewardHundredths'] as int,
    claimAccount: json['claimAccount'] as String,
    accountName: json['accountName'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'claimedAt': claimedAt.toIso8601String(),
    'rewardHundredths': rewardHundredths,
    'claimAccount': claimAccount,
    'accountName': accountName,
  };
}
