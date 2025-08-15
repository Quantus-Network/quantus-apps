import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

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
        print('error adding account $e $st');
        // Handle error, maybe revert state or show a message
      }
    });
  }

  Future<void> removeAccount(Account account) async {
    state.whenData((accounts) async {
      try {
        await _accountsService.removeAccount(account);
        final newAccounts = accounts
            .where((a) => a.index != account.index)
            .toList();
        state = AsyncValue.data(newAccounts);
      } catch (e, st) {
        print('remove account error $e $st');
      }
    });
  }
}

final accountsProvider =
    StateNotifierProvider<AccountsNotifier, AsyncValue<List<Account>>>((ref) {
      final accountsService = ref.watch(accountsServiceProvider);
      return AccountsNotifier(accountsService);
    });

class ActiveAccountNotifier extends StateNotifier<AsyncValue<Account?>> {
  final SettingsService _settingsService;

  ActiveAccountNotifier(this._settingsService)
    : super(const AsyncValue.loading()) {
    _loadActiveAccount();
  }

  Future<void> _loadActiveAccount() async {
    try {
      final account = await _settingsService.getActiveAccount();
      state = AsyncValue.data(account);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setActiveAccount(Account account) async {
    try {
      await _settingsService.setActiveAccount(account);
      state = AsyncValue.data(account);
    } catch (e, st) {
      print('setActiveAccount error $e $st');
    }
  }
}

final activeAccountProvider =
    StateNotifierProvider<ActiveAccountNotifier, AsyncValue<Account?>>((ref) {
      final settingsService = ref.watch(settingsServiceProvider);
      return ActiveAccountNotifier(settingsService);
    });
