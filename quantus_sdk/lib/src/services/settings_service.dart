import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();

  // New keys for multi-account support
  static const String _accountsKey = 'accounts_v3';
  static const String _accountsToMigrateKey = 'accounts_to_migrate';

  static const String _accountsKeyV2 = 'accounts_v2';
  static const String _oldAccountsKey = 'accounts';
  static const String _activeAccountIndexKey = 'active_account_index';

  // Local authentication keys
  static const String _isLocalAuthEnabledKey = 'is_local_auth_enabled';
  static const String _lastSuccessfulAuthKey = 'last_successful_auth';

  Future<void> initialize() async {
    // Always (re)bind the SharedPreferences instance. This ensures tests that
    // call SharedPreferences.setMockInitialValues({}) before initialize()
    // get a clean, isolated preferences store even if the service singleton
    // was created earlier in the process.
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Multi-Account Methods ---

  Future<List<Account>> getAccounts() async {
    final accountsJson = _prefs.getString(_accountsKey);
    if (accountsJson != null) {
      final decoded = jsonDecode(accountsJson) as List<dynamic>;
      return decoded.map((e) => Account.fromJson(e)).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
    }
    // Migration for existing single-account users
    final oldAccountId = _prefs.getString('account_id');
    if (oldAccountId != null) {
      final oldWalletName = _prefs.getString('wallet_name') ?? 'Account 1';
      final account = Account(
        index: 0,
        name: oldWalletName,
        accountId: oldAccountId,
      );
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
    final List<Map<String, dynamic>> jsonData = accounts
        .map((a) => a.toJson())
        .toList();
    await _prefs.setString(_accountsKey, jsonEncode(jsonData));
  }

  // --- Accounts To Migrate (for deferred upload) ---
  Future<void> setAccountsToMigrate(List<Account> accounts) async {
    final List<Map<String, dynamic>> jsonData = accounts
        .map((a) => a.toJson())
        .toList();
    await _prefs.setString(_accountsToMigrateKey, jsonEncode(jsonData));
  }

  List<Account> getAccountsToMigrate() {
    final jsonStr = _prefs.getString(_accountsToMigrateKey);
    if (jsonStr == null) return [];
    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded.map((e) => Account.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearAccountsToMigrate() async {
    await _prefs.remove(_accountsToMigrateKey);
  }

  Future<void> addAccount(Account account) async {
    final accounts = await getAccounts();
    // Check for duplicates by index or accountId before adding
    if (!accounts.any(
      (a) => a.index == account.index || a.accountId == account.accountId,
    )) {
      accounts.add(account);
      await saveAccounts(accounts);
      if (accounts.length == 1) {
        // make sure that active account is always a valid account
        await setActiveAccount(account);
      }
    } else {
      throw Exception('Account already exists');
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
    if (accounts.length == 1) {
      throw Exception('Cant remove last account!');
    }
    if (account.index == 0) {
      throw Exception("Can't remove the root account");
    }
    if (account.index == _getActiveAccountIndex()) {
      _setActiveAccountIndex(accounts[0].index);
    }
    accounts.removeWhere((a) => a.index == account.index);
    await saveAccounts(accounts);
  }

  Future<void> setActiveAccount(Account account) async {
    final accountExists = await getAccount(account.index);
    if (accountExists != null) {
      _setActiveAccountIndex(account.index);
    } else {
      throw Exception('Account index does not exist');
    }
  }

  int _getActiveAccountIndex() {
    return _prefs.getInt(_activeAccountIndexKey) ?? 0;
  }

  void _setActiveAccountIndex(int index) {
    final oldIndex = _getActiveAccountIndex();
    if (index != oldIndex) {
      _prefs.setInt(_activeAccountIndexKey, index);
    }
  }

  Future<Account?> getActiveAccount() async {
    final activeIndex = _getActiveAccountIndex();
    return getAccount(activeIndex);
  }

  Future<Account?> getAccount(int index) async {
    final accounts = await getAccounts();
    final ix = accounts.indexWhere((a) => a.index == index);
    return ix != -1 ? accounts[ix] : null;
  }

  Future<int> getNextFreeAccountIndex() async {
    final accounts = await getAccounts();
    final maxIndex = accounts
        .map((a) => a.index)
        .reduce((a, b) => a > b ? a : b);
    return maxIndex + 1;
  }

  // --- End Multi-Account Methods ---

  Future<bool> getHasWallet() async {
    final accounts = await getAccounts();
    return accounts.isNotEmpty;
  }

  Future<bool> isWalletLoggedOut() async {
    final accounts = await getAccounts();
    return accounts.isEmpty;
  }

  // Mnemonic Settings - Using secure storage
  Future<void> setMnemonic(String mnemonic) async {
    await _secureStorage.write(key: 'mnemonic', value: mnemonic);
  }

  Future<String?> getMnemonic() async {
    return await _secureStorage.read(key: 'mnemonic');
  }

  // Reversible Time Settings
  Future<void> setReversibleTimeSeconds(int seconds) async {
    await _prefs.setInt('reversible_time_seconds', seconds);
  }

  Future<int?> getReversibleTimeSeconds() async {
    return _prefs.getInt('reversible_time_seconds');
  }

  // --- Primitive Accessors for General Use ---

  /// Get a boolean value from SharedPreferences
  Future<bool?> getBool(String key) async {
    return _prefs.getBool(key);
  }

  /// Set a boolean value in SharedPreferences
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  /// Get a string value from SharedPreferences
  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  DateTime? getLastSuccessfulAuthTime() {
    final String? lastAuthString = _prefs.getString(_lastSuccessfulAuthKey);
    if (lastAuthString == null) return null;

    final DateTime lastAuth = DateTime.parse(lastAuthString);
    return lastAuth;
  }

  void setLastSuccessfulAuthTime(DateTime time) {
    _prefs.setString(_lastSuccessfulAuthKey, time.toIso8601String());
  }

  void setAuthEnabled(bool enabled) {
    _prefs.setBool(_isLocalAuthEnabledKey, enabled);
  }

  bool isAuthEnabled() {
    return _prefs.getBool(_isLocalAuthEnabledKey) ?? false;
  }

  // --- Migration Methods ---

  /// Check if old accounts exist in legacy storage
  bool hasOldAccounts() {
    final oldAccounts = getOldAccounts();
    return oldAccounts.isNotEmpty;
  }

  /// Get old accounts from legacy storage or v2 storage
  List<Account> getOldAccounts() {
    final oldAccountsJson = _prefs.getString(_oldAccountsKey) ?? _prefs.getString(_accountsKeyV2);
    if (oldAccountsJson != null) {
      try {
        final decoded = jsonDecode(oldAccountsJson) as List<dynamic>;
        return decoded.map((e) => Account.fromJson(e)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  /// Remove old accounts from legacy storage after successful migration
  Future<void> clearOldAccounts() async {
    await _prefs.remove(_oldAccountsKey);
    await _prefs.remove(_accountsKeyV2);
  }

  /// Set old accounts data (for debugging/testing)
  Future<void> setOldAccountsData(String jsonData) async {
    print('removing accounts data');
    await _prefs.remove(_accountsKey);
    print('setting old accounts data - reload app after this');
    // await _prefs.setString(_accountsKeyV2, jsonData); // test mid new accts - also works
    await _prefs.setString(_oldAccountsKey, jsonData);
  }

  // Test-only helper to reset initialization between tests
  void resetForTest() {
    assert(() {
      // _initialized = false;
      return true;
    }());
  }

  // Clear all settings
  Future<void> clearAll() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }
}
