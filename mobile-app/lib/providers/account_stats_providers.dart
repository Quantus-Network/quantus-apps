import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class AccountStatsNotifier extends StateNotifier<AsyncValue<AccountStats>> {
  final TaskmasterService _taskmasterService = TaskmasterService();

  AccountStatsNotifier() : super(const AsyncValue.loading()) {
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      // Fetch both stats concurrently
      final [accountStatsRes, minerStatsRes] = await Future.wait([
        _taskmasterService.getAccountStats(),
        _taskmasterService.getMinerStats(),
      ]);

      // For now task master can't figure this out yet so lets do it locally
      final minerStats = minerStatsRes as MinerStats;
      final s = accountStatsRes as AccountStats;
      final accountStats = AccountStats(
        referralCount: s.referralCount,
        sendCount: s.sendCount,
        reversalCount: s.reversalCount,
        miningCount: minerStats.totalMinedBlocks,
        miningRewards: minerStats.totalRewards,
      );

      state = AsyncValue.data(accountStats);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}

final accountsStatsProvider =
    StateNotifierProvider<AccountStatsNotifier, AsyncValue<AccountStats>>((
      ref,
    ) {
      return AccountStatsNotifier();
    });
