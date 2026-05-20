import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';

class RaiderSubmissionsNotifier extends StateNotifier<AsyncValue<RaiderSubmissionsState>> {
  final TaskmasterService _taskmasterService = TaskmasterService();
  final Account? _account;

  RaiderSubmissionsNotifier(this._account) : super(const AsyncValue.loading()) {
    if (_account != null) {
      fetchRaiderSubmissions();
    }
  }

  Future<void> fetchRaiderSubmissions() async {
    if (_account == null) return;

    try {
      final submissions = await _taskmasterService.getActiveRaidRaiderSubmissions();
      if (mounted) {
        state = AsyncValue.data(submissions);
      }
    } catch (e, st) {
      print('Error fetching raider submissions: $e');
      print('Stack trace: $st');

      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}

final raiderSubmissionsProvider = StateNotifierProvider<RaiderSubmissionsNotifier, AsyncValue<RaiderSubmissionsState>>((
  ref,
) {
  final activeAccount = ref.watch(activeAccountProvider).value;
  return RaiderSubmissionsNotifier(activeAccount is RegularAccount ? activeAccount.account : null);
});
