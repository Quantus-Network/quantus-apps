import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class AccountAssociationsNotifier extends StateNotifier<AsyncValue<AccountAssociations>> {
  final TaskmasterService _taskmasterService = TaskmasterService();

  AccountAssociationsNotifier() : super(const AsyncValue.loading()) {
    fetchAssociations();
  }

  Future<void> fetchAssociations() async {
    try {
      final associations = await _taskmasterService.getAccountAssociations();

      state = AsyncValue.data(associations);
    } catch (e, st) {
      print('Error fetching account associations: $e');
      print('Stack trace: $st');

      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}

final accountAssociationsProvider = StateNotifierProvider<AccountAssociationsNotifier, AsyncValue<AccountAssociations>>(
  (ref) {
    return AccountAssociationsNotifier();
  },
);
