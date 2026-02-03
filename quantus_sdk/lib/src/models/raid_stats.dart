import 'package:flutter/foundation.dart';

@immutable
class RaidStats {
  final int raidId;
  final int rank;
  final int totalSubmissions;
  final int totalImpressions;
  final int totalReplies;
  final int totalRetweets;
  final int totalLikes;

  const RaidStats({
    required this.raidId,
    required this.rank,
    required this.totalSubmissions,
    required this.totalImpressions,
    required this.totalReplies,
    required this.totalRetweets,
    required this.totalLikes,
  });

  factory RaidStats.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return RaidStats(
      raidId: data['raid_id'] as int,
      rank: data['rank'] as int,
      totalSubmissions: data['total_submissions'] as int,
      totalImpressions: data['total_impressions'] as int,
      totalReplies: data['total_replies'] as int,
      totalRetweets: data['total_retweets'] as int,
      totalLikes: data['total_likes'] as int,
    );
  }
}
