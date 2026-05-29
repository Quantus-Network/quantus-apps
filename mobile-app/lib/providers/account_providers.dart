import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class AccountsNotifier extends StateNotifier<AsyncValue<List<Account>>> {
  final AccountsService _accountsService;

  AccountsNotifier(this._accountsService) : super(const AsyncValue.loading()) {
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _accountsService.getAccounts();
      state = AsyncValue.data(accounts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addAccount(Account account) async {
    state.whenData((accounts) async {
      try {
        await _accountsService.addAccount(account);
        state = AsyncValue.data([...accounts, account]);
      } catch (e, st) {
        quantusDebugPrint('error adding account $e $st');
        // Handle error, maybe revert state or show a message
      }
    });
  }

  Future<void> removeAccount(Account account) async {
    state.whenData((accounts) async {
      try {
        await _accountsService.removeAccount(account);
        final newAccounts = accounts.where((a) => a.accountId != account.accountId).toList();
        state = AsyncValue.data(newAccounts);
      } catch (e, st) {
        quantusDebugPrint('remove account error $e $st');
      }
    });
  }

  Account? getAccountWithId(String accountId) {
    return state.value?.firstWhere((account) => account.accountId == accountId);
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}

final accountsProvider = StateNotifierProvider<AccountsNotifier, AsyncValue<List<Account>>>((ref) {
  final accountsService = ref.watch(accountsServiceProvider);
  return AccountsNotifier(accountsService);
});

class ActiveAccountNotifier extends StateNotifier<AsyncValue<DisplayAccount?>> {
  final SettingsService _settingsService;

  ActiveAccountNotifier(this._settingsService) : super(const AsyncValue.loading()) {
    _loadActiveAccount();
  }

  Future<void> _loadActiveAccount() async {
    try {
      final account = await _settingsService.getActiveAccount();
      quantusDebugPrint('loaded active account: ${account?.account.name}');
      state = AsyncValue.data(account);
    } catch (e, st) {
      quantusDebugPrint('error loading active account: $e $st');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setActiveAccount(DisplayAccount account) async {
    try {
      await _settingsService.setActiveAccount(account);
      state = AsyncValue.data(account);
    } catch (e, st) {
      quantusDebugPrint('setActiveAccount error $e $st');
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}

final activeAccountProvider = StateNotifierProvider<ActiveAccountNotifier, AsyncValue<DisplayAccount?>>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return ActiveAccountNotifier(settingsService);
});
