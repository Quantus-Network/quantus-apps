import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

// Union type for display accounts
sealed class DisplayAccount {
  const DisplayAccount();

  BaseAccount get account;
}

class RegularAccount extends DisplayAccount {
  @override
  final Account account;
  const RegularAccount(this.account);
}

class EntrustedDisplayAccount extends DisplayAccount {
  @override
  final EntrustedAccount account;
  const EntrustedDisplayAccount(this.account);
}

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
        final newAccounts = accounts.where((a) => a.index != account.index).toList();
        state = AsyncValue.data(newAccounts);
      } catch (e, st) {
        print('remove account error $e $st');
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

class ActiveAccountNotifier extends StateNotifier<AsyncValue<Account?>> {
  final SettingsService _settingsService;

  ActiveAccountNotifier(this._settingsService) : super(const AsyncValue.loading()) {
    _loadActiveAccount();
  }

  Future<void> _loadActiveAccount() async {
    try {
      final account = await _settingsService.getActiveAccount();
      print('loaded active account: ${account?.index} ${account?.name}');
      state = AsyncValue.data(account);
    } catch (e, st) {
      print('error loading acctive account: $e $st');
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

  void reset() {
    state = const AsyncValue.loading();
  }
}

final activeAccountProvider = StateNotifierProvider<ActiveAccountNotifier, AsyncValue<Account?>>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return ActiveAccountNotifier(settingsService);
});

class ActiveDisplayAccountNotifier extends StateNotifier<AsyncValue<DisplayAccount?>> {
  final SettingsService _settingsService;

  ActiveDisplayAccountNotifier(this._settingsService) : super(const AsyncValue.loading()) {
    _loadActiveDisplayAccount();
  }

  Future<void> _loadActiveDisplayAccount() async {
    try {
      final account = await _settingsService.getActiveAccount();
      if (account != null) {
        state = AsyncValue.data(RegularAccount(account));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setActiveDisplayAccount(DisplayAccount displayAccount) async {
    try {
      switch (displayAccount) {
        case RegularAccount(account: final account):
          await _settingsService.setActiveAccount(account);
          state = AsyncValue.data(displayAccount);
        case EntrustedDisplayAccount():
          // For entrusted accounts, we don't save them as active account in settings
          // They are temporary display accounts
          state = AsyncValue.data(displayAccount);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}

final activeDisplayAccountProvider = StateNotifierProvider<ActiveDisplayAccountNotifier, AsyncValue<DisplayAccount?>>((
  ref,
) {
  final settingsService = ref.watch(settingsServiceProvider);
  return ActiveDisplayAccountNotifier(settingsService);
});
