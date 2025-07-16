import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:ss58/ss58.dart';
import 'package:quantus_sdk/src/models/account.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();
  bool _initialized = false;

  // New keys for multi-account support
  static const String _accountsKey = 'accounts';
  static const String _activeAccountIndexKey = 'active_account_index';

  Future<void> initialize() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  // --- New Multi-Account Methods ---

  Future<List<Account>> getAccounts() async {
    await _ensureInitialized();
    final accountsJson = _prefs.getString(_accountsKey);
    if (accountsJson != null) {
      final List<dynamic> decoded = jsonDecode(accountsJson);
      return decoded.map((e) => Account.fromJson(e)).toList();
    }

    // Migration for existing single-account users
    final oldAccountId = _prefs.getString('account_id');
    if (oldAccountId != null) {
      final oldWalletName = _prefs.getString('wallet_name') ?? 'Account 1';
      final account = Account(index: 0, name: oldWalletName, accountId: oldAccountId);
      await saveAccounts([account]);
      await setActiveAccount(account);
      // Clean up old keys after migration
      await _prefs.remove('account_id');
      await _prefs.remove('wallet_name');
      return [account];
    }

    return [];
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    await _ensureInitialized();
    final List<Map<String, dynamic>> jsonData = accounts.map((a) => a.toJson()).toList();
    await _prefs.setString(_accountsKey, jsonEncode(jsonData));
  }

  Future<void> addAccount(Account account) async {
    final accounts = await getAccounts();
    // Check for duplicates by index or accountId before adding
    if (!accounts.any((a) => a.index == account.index || a.accountId == account.accountId)) {
      accounts.add(account);
      await saveAccounts(accounts);
    }
  }

  Future<void> updateAccount(Account account) async {
    final accounts = await getAccounts();
    final index = accounts.indexWhere((a) => a.index == account.index);
    if (index != -1) {
      accounts[index] = account;
      await saveAccounts(accounts);
    }
  }

  Future<void> removeAccount(Account account) async {
    final accounts = await getAccounts();
    accounts.removeWhere((a) => a.index == account.index);
    await saveAccounts(accounts);
  }

  Future<void> setActiveAccount(Account account) async {
    await _ensureInitialized();
    await _prefs.setInt(_activeAccountIndexKey, account.index);
  }

  Future<Account?> getActiveAccount() async {
    await _ensureInitialized();
    final accounts = await getAccounts();
    if (accounts.isEmpty) {
      return null;
    }
    final activeIndex = _prefs.getInt(_activeAccountIndexKey) ?? 0;
    // Ensure index is valid
    if (activeIndex >= 0 && activeIndex < accounts.length) {
      final account = accounts.firstWhere((a) => a.index == activeIndex, orElse: () => accounts.first);
      return account;
    }
    return accounts.first;
  }

  Future<void> clearActiveAccount() async {
    await _ensureInitialized();
    await _prefs.remove(_activeAccountIndexKey);
  }

  // --- End New Multi-Account Methods ---

  // Account Settings
  @Deprecated('Use getActiveAccount() instead')
  Future<void> setAccountId(String accountId) async {
    await _ensureInitialized();
    await _prefs.setString('account_id', accountId);
  }

  @Deprecated('Use getActiveAccount() instead')
  Future<String?> getAccountId() async {
    await _ensureInitialized();
    final account = await getActiveAccount();
    return account?.accountId;
  }

  @Deprecated('Use removeAccount() and clearActiveAccount() instead')
  Future<void> clearAccountId() async {
    await _ensureInitialized();
    await _prefs.remove('account_id');
  }

  // Wallet Name Settings
  @Deprecated('Use updateAccount() instead')
  Future<void> setWalletName(String name) async {
    await _ensureInitialized();
    final account = await getActiveAccount();
    if (account != null) {
      final updatedAccount = account.copyWith(name: name);
      await updateAccount(updatedAccount);
    }
  }

  @Deprecated('Use getActiveAccount() instead')
  Future<String?> getWalletName() async {
    await _ensureInitialized();
    final account = await getActiveAccount();
    return account?.name;
  }

  // Wallet Existence
  Future<void> setHasWallet(bool hasWallet) async {
    await _ensureInitialized();
    await _prefs.setBool('has_wallet', hasWallet);
  }

  Future<bool> getHasWallet() async {
    await _ensureInitialized();
    return _prefs.getBool('has_wallet') ?? false;
  }

  // Mnemonic Settings - Using secure storage
  Future<void> setMnemonic(String mnemonic) async {
    await _ensureInitialized();
    await _secureStorage.write(key: 'mnemonic', value: mnemonic);
  }

  Future<String?> getMnemonic() async {
    await _ensureInitialized();
    return await _secureStorage.read(key: 'mnemonic');
  }

  Future<void> clearMnemonic() async {
    await _ensureInitialized();
    await _secureStorage.delete(key: 'mnemonic');
  }

  // Reversible Time Settings
  Future<void> setReversibleTimeSeconds(int seconds) async {
    await _ensureInitialized();
    await _prefs.setInt('reversible_time_seconds', seconds);
  }

  Future<int?> getReversibleTimeSeconds() async {
    await _ensureInitialized();
    return _prefs.getInt('reversible_time_seconds');
  }

  // Clear all settings
  Future<void> clearAll() async {
    await _ensureInitialized();
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }

  // Helper method to ensure initialization
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }
}
