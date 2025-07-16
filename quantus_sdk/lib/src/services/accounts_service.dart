import 'package:quantus_sdk/quantus_sdk.dart';

// We define the following 5 levels in BIP32 path:
// m / purpose' / coin_type' / account' / change / address_index
// For Quantus purpose should be 189 or if that's not available maybe 1899
// coin type should be 0 for native
// account is the account index - 1, 2, 3...
// change and address index should remain at 0

// Bip44 describes account discovery from seed phrase - it keeps looking by increasing acocunt index, for accounts with activity.
// It defines the max allowed account gap as 20, if there's 20 addresses in a row where there's no activity, it assumes the highest index has been reached.

class AccountsService {
  static final AccountsService _instance = AccountsService._internal();
  factory AccountsService() => _instance;
  AccountsService._internal();

  final SettingsService _settingsService = SettingsService();

  Future<Account> createNewAccount(String name) async {
    final mnemonic = await _settingsService.getMnemonic();

    if (mnemonic == null) {
      throw Exception('Mnemonic not found. Cannot create new account.');
    }

    // Determine the next index for derivation
    // Note: child indexes start at 1. Index 0 is the root account with NO derivation.
    final nextIndex = await _settingsService.getNextFreeAccountIndex();

    final keypair = HdWalletService().keyPairAtIndex(mnemonic, nextIndex);

    final newAccount = Account(
      index: nextIndex,
      name: name.isEmpty ? 'Account ${nextIndex + 1}' : name,
      accountId: keypair.ss58Address,
    );

    // Save the new account
    await _settingsService.addAccount(newAccount);
    await _settingsService.setActiveAccount(newAccount);

    return newAccount;
  }
}
