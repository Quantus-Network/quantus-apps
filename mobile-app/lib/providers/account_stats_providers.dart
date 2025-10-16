import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class AccountStatsNotifier extends StateNotifier<AsyncValue<AccountStats>> {
  final TaskmasterService _taskmasterService = TaskmasterService();

  AccountStatsNotifier() : super(const AsyncValue.loading()) {
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      final accountStats = await _taskmasterService.getAccountStats();
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
