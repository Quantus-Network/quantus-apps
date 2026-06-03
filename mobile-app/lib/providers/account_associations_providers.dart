import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class AccountAssociationsNotifier extends StateNotifier<AsyncValue<AccountAssociations>> {
  final TaskmasterService _taskmasterService = TaskmasterService();
  final Account? _account;

  AccountAssociationsNotifier(this._account) : super(const AsyncValue.loading()) {
    if (_account != null) {
      fetchAssociations();
    }
  }

  Future<void> fetchAssociations() async {
    if (_account == null) return;

    try {
      final associations = await _taskmasterService.getAccountAssociations();
      if (mounted) {
        state = AsyncValue.data(associations);
      }
    } catch (e, st) {
      quantusDebugPrint('Error fetching account associations: $e');
      quantusDebugPrint('Stack trace: $st');

      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}

final accountAssociationsProvider = StateNotifierProvider<AccountAssociationsNotifier, AsyncValue<AccountAssociations>>(
  (ref) {
    final activeAccount = ref.watch(activeAccountProvider).value;
    return AccountAssociationsNotifier(activeAccount is RegularAccount ? activeAccount.account : null);
  },
);
