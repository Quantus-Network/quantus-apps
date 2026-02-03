import 'package:flutter/foundation.dart';

@immutable
class ReferralRank {
  final int rank;
  final int referralsCount;

  const ReferralRank({required this.rank, required this.referralsCount});

  factory ReferralRank.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>;
    if (data.isEmpty) {
      return const ReferralRank(rank: 0, referralsCount: 0);
    }
    final first = data[0] as Map<String, dynamic>;
    return ReferralRank(rank: first['rank'] as int, referralsCount: first['address']['referrals_count'] as int);
  }
}
