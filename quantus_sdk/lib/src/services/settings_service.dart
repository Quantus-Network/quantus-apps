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

  // --- Multi-Account Methods ---

  Future<List<Account>> getAccounts() async {
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

    throw Exception('Wallet is logged out.');
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    final List<Map<String, dynamic>> jsonData = accounts.map((a) => a.toJson()).toList();
    await _prefs.setString(_accountsKey, jsonEncode(jsonData));
  }

  Future<void> addAccount(Account account) async {
    final accounts = await getAccounts();
    // Check for duplicates by index or accountId before adding
    if (!accounts.any((a) => a.index == account.index || a.accountId == account.accountId)) {
      accounts.add(account);
      await saveAccounts(accounts);
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
    final exists = (await getAccount(account.index)) != null;
    if (exists) {
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
      notifyActiveAccountChanged();
    }
  }

  Future<void> notifyActiveAccountChanged() async {
    print('TBD: notify listeners that active account has changed');
  }

  Future<Account> getActiveAccount() async {
    final activeIndex = _getActiveAccountIndex();
    return (await getAccount(activeIndex))!;
  }

  Future<Account?> getAccount(int index) async {
    final accounts = await getAccounts();
    final ix = accounts.indexWhere((a) => a.index == index);
    return ix != -1 ? accounts[ix] : null;
  }

  Future<int> getNextFreeAccountIndex() async {
    final accounts = await getAccounts();
    final maxIndex = accounts.map((a) => a.index).reduce((a, b) => a > b ? a : b);
    return maxIndex + 1;
  }

  // --- End Multi-Account Methods ---

  Future<bool> getHasWallet() async {
    final accounts = await getAccounts();
    return accounts.isNotEmpty;
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

  // Clear all settings
  Future<void> clearAll() async {
    await _prefs.clear();
    await _secureStorage.deleteAll();
  }

}
