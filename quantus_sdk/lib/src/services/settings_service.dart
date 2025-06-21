import 'package:quantus_sdk/secure_storage_service.dart';
import 'package:quantus_sdk/preferences_storage_service.dart';

class SettingsService {
  final SecureStorageService _secureStorage;
  final PreferencesStorageService _prefsStorage;

  SettingsService(this._secureStorage, this._prefsStorage);

  // Account Settings
  Future<void> setAccountId(String accountId) async {
    await _prefsStorage.write(key: 'account_id', value: accountId);
  }

  Future<String?> getAccountId() async {
    return _prefsStorage.read(key: 'account_id');
  }

  Future<void> clearAccountId() async {
    await _prefsStorage.delete(key: 'account_id');
  }

  // Wallet Name Settings
  Future<void> setWalletName(String name) async {
    await _prefsStorage.write(key: 'wallet_name', value: name);
  }

  Future<String?> getWalletName() async {
    return _prefsStorage.read(key: 'wallet_name');
  }

  // Wallet Existence
  Future<void> setHasWallet(bool hasWallet) async {
    await _prefsStorage.setBool('has_wallet', hasWallet);
  }

  Future<bool> getHasWallet() async {
    return await _prefsStorage.getBool('has_wallet') ?? false;
  }

  // Mnemonic Settings - Using secure storage
  Future<void> setMnemonic(String mnemonic) async {
    await _secureStorage.write(key: 'mnemonic', value: mnemonic);
  }

  Future<String?> getMnemonic() async {
    // TODO remove this at launch
    final mnemonicInPrefs = await _prefsStorage.read(key: 'mnemonic');
    if (mnemonicInPrefs != null) {
      // In a pure dart environment, we can't use debugPrint
      // print('mnemonic found in prefs - transferring to secure storage');
      await setMnemonic(mnemonicInPrefs);
      await _prefsStorage.delete(key: 'mnemonic');
      return mnemonicInPrefs;
    }

    return await _secureStorage.read(key: 'mnemonic');
  }

  Future<void> clearMnemonic() async {
    await _secureStorage.delete(key: 'mnemonic');
  }

  // Clear all settings
  Future<void> clearAll() async {
    await _prefsStorage.deleteAll();
    await _secureStorage.deleteAll();
  }
}
