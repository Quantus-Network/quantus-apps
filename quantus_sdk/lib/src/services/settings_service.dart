import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/display_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();

  // New keys for multi-account support
  static const String _accountsKey = 'accounts_v4';
  static const String _accountsToMigrateKey = 'accounts_to_migrate';
  static const String _addressBookKey = 'address_book';

  static const String _oldAccountsKeyV3 = 'accounts_v3';
  static const String _oldAccountsKeyV2 = 'accounts_v2';
  static const String _oldAccountsKeyV1 = 'accounts';
  static const String _activeAccountIndexKey = 'active_account_index';
  static const String _activeAccountIdKey = 'active_account_id';
  static const String _activeDisplayAccountKey = 'active_display_account';
  static const String _balanceHiddenKey = 'balance_hidden';

  static const String _lastPausedTimeKey = 'last_paused_time';

  // referral status
  static const String hasCheckedReferralKey = 'referral_check';
  static const String referralCodeKey = 'referral_code';
  static const String hasWatchedQuestsPromoKey = 'quests_promo';
  static const String existingUserSeenPromoVideoKey = 'existing_user_seen_promo_video';

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
      return decoded.map((e) => Account.fromJson(e)).toList()..sort(
        (a, b) => a.walletIndex != b.walletIndex ? a.walletIndex.compareTo(b.walletIndex) : a.index.compareTo(b.index),
      );
    }
    // Migration for existing single-account users
    final oldAccountId = _prefs.getString('account_id');
    if (oldAccountId != null) {
      final oldWalletName = _prefs.getString('wallet_name') ?? 'Account 1';
      final account = Account(walletIndex: 0, index: 0, name: oldWalletName, accountId: oldAccountId);
      await saveAccounts([account]);
      await setActiveAccount(RegularAccount(account));
      // Clean up old keys after migration
      await _prefs.remove('account_id');
      await _prefs.remove('wallet_name');
      return [account];
    }

    return [];
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    final List<Map<String, dynamic>> jsonData = accounts.map((a) => a.toJson()).toList();
    await _prefs.setString(_accountsKey, jsonEncode(jsonData));
  }

  // --- Accounts To Migrate (for deferred upload) ---
  Future<void> setAccountsToMigrate(List<Account> accounts) async {
    final List<Map<String, dynamic>> jsonData = accounts.map((a) => a.toJson()).toList();
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
      (a) => (a.walletIndex == account.walletIndex && a.index == account.index) || a.accountId == account.accountId,
    )) {
      accounts.add(account);
      await saveAccounts(accounts);
      if (accounts.length == 1) {
        // make sure that active account is always a valid account
        await setActiveAccount(RegularAccount(account));
      }
    } else {
      throw Exception('Account already exists');
    }
  }

  Future<void> updateAccount(Account account) async {
    final accounts = await getAccounts();
    final index = accounts.indexWhere((a) => a.accountId == account.accountId);
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
    if (account.accountId == await _getActiveAccountId()) {
      await setActiveAccount(RegularAccount(accounts[0]));
    }
    accounts.removeWhere((a) => a.accountId == account.accountId);
    await saveAccounts(accounts);
  }

  Future<void> setActiveAccount(DisplayAccount account) async {
    await _prefs.setString(_activeDisplayAccountKey, jsonEncode(account.toJson()));
    if (account is RegularAccount) {
      final exists = (await getAccounts()).any((a) => a.accountId == account.account.accountId);
      if (exists) {
        await _setActiveAccountId(account.account.accountId);
      } else {
        throw Exception('Account index does not exist');
      }
    }
  }

  Future<DisplayAccount?> getActiveAccount() async {
    final jsonStr = _prefs.getString(_activeDisplayAccountKey);
    if (jsonStr != null) {
      return DisplayAccount.fromJson(jsonDecode(jsonStr));
    }
    final activeAccountId = await _getActiveAccountId();
    final accounts = await getAccounts();
    final ix = accounts.indexWhere((a) => a.accountId == activeAccountId);
    return ix != -1 ? RegularAccount(accounts[ix]) : (accounts.isNotEmpty ? RegularAccount(accounts.first) : null);
  }

  Future<Account?> getActiveRegularAccount() async {
    final activeAccount = await getActiveAccount();
    if (activeAccount is RegularAccount) {
      return activeAccount.account;
    }
    return null;
  }

  Future<String?> _getActiveAccountId() async {
    final id = _prefs.getString(_activeAccountIdKey);
    if (id != null && id.isNotEmpty) return id;

    final legacyIndex = _getActiveAccountIndex();
    final accounts = await getAccounts();
    if (accounts.isEmpty) return null;
    final legacyAccount = accounts.firstWhere(
      (a) => a.walletIndex == 0 && a.index == legacyIndex,
      orElse: () => accounts.first,
    );

    await _setActiveAccountId(legacyAccount.accountId);
    return legacyAccount.accountId;
  }

  int _getActiveAccountIndex() {
    return _prefs.getInt(_activeAccountIndexKey) ?? 0;
  }

  Future<void> _setActiveAccountId(String accountId) async {
    final oldId = _prefs.getString(_activeAccountIdKey);
    if (oldId != accountId) {
      await _prefs.setString(_activeAccountIdKey, accountId);
    }
  }

  Future<Account?> getAccount({required int walletIndex, required int index}) async {
    final accounts = await getAccounts();
    final ix = accounts.indexWhere((a) => a.walletIndex == walletIndex && a.index == index);
    return ix != -1 ? accounts[ix] : null;
  }

  Future<int> getNextFreeAccountIndex(int walletIndex) async {
    final accounts = await getAccounts();
    final walletAccounts = accounts.where((a) => a.walletIndex == walletIndex && a.index >= 0).toList();
    if (walletAccounts.isEmpty) return 0;
    final maxIndex = walletAccounts.map((a) => a.index).reduce((a, b) => a > b ? a : b);
    return maxIndex + 1;
  }

  // --- Address Book Methods ---

  Future<Map<String, String>> getAddressBook() async {
    final jsonStr = _prefs.getString(_addressBookKey);
    if (jsonStr == null) return {};
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((key, value) => MapEntry(key, value as String));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAddressBook(Map<String, String> addressBook) async {
    await _prefs.setString(_addressBookKey, jsonEncode(addressBook));
  }

  Future<void> setAddressName(String address, String name) async {
    final addressBook = await getAddressBook();
    addressBook[address] = name;
    await saveAddressBook(addressBook);
  }

  Future<String?> getAddressName(String address) async {
    final addressBook = await getAddressBook();
    return addressBook[address];
  }

  Future<void> removeAddressName(String address) async {
    final addressBook = await getAddressBook();
    addressBook.remove(address);
    await saveAddressBook(addressBook);
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

  String getMnemonicKey(int walletIndex) => walletIndex == 0 ? 'mnemonic' : 'mnemonic_$walletIndex';

  // Mnemonic Settings - Using secure storage
  Future<void> setMnemonic(String mnemonic, int walletIndex) async {
    await _secureStorage.write(key: getMnemonicKey(walletIndex), value: mnemonic);
  }

  Future<String?> getMnemonic(int walletIndex) async {
    return await _secureStorage.read(key: getMnemonicKey(walletIndex));
  }

  // Reversible Transaction Settings
  Future<void> setReversibleEnabled(bool enabled) async {
    await _prefs.setBool('reversible_enabled', enabled);
  }

  bool isReversibleEnabled() {
    return _prefs.getBool('reversible_enabled') ?? false;
  }

  Future<void> setReversibleTimeSeconds(int seconds) async {
    await _prefs.setInt('reversible_time_seconds', seconds);
  }

  Future<int?> getReversibleTimeSeconds() async {
    return _prefs.getInt('reversible_time_seconds');
  }

  // Balance Hidden Settings
  Future<void> setBalanceHidden(bool hidden) async {
    await _prefs.setBool(_balanceHiddenKey, hidden);
  }

  bool isBalanceHidden() {
    return _prefs.getBool(_balanceHiddenKey) ?? false;
  }

  // POS Mode Settings
  static const String _posModeEnabledKey = 'pos_mode_enabled';

  Future<void> setPosModeEnabled(bool enabled) async {
    await _prefs.setBool(_posModeEnabledKey, enabled);
  }

  bool isPosModeEnabled() {
    return _prefs.getBool(_posModeEnabledKey) ?? false;
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

  DateTime? getLastPausedTime() {
    final String? lastPausedString = _prefs.getString(_lastPausedTimeKey);
    if (lastPausedString == null) return null;

    final DateTime lastPaused = DateTime.parse(lastPausedString);
    return lastPaused;
  }

  void setLastPausedTime(DateTime time) {
    _prefs.setString(_lastPausedTimeKey, time.toIso8601String());
  }

  void cleanLastPausedTime() {
    _prefs.remove(_lastPausedTimeKey);
  }

  // --- Migration Methods ---

  /// Check if old accounts exist in legacy storage
  bool hasOldAccounts() {
    final oldAccounts = getOldAccounts();
    return oldAccounts.isNotEmpty;
  }

  /// Get old accounts from legacy storage or v2 storage
  List<Account> getOldAccounts() {
    final oldAccountsJson =
        _prefs.getString(_oldAccountsKeyV1) ??
        _prefs.getString(_oldAccountsKeyV2) ??
        _prefs.getString(_oldAccountsKeyV3);
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
    await _prefs.remove(_oldAccountsKeyV1);
    await _prefs.remove(_oldAccountsKeyV2);
    await _prefs.remove(_oldAccountsKeyV3);
  }

  /// Set old accounts data (for debugging/testing)
  Future<void> setOldAccountsData(String jsonData) async {
    print('removing accounts data');
    await _prefs.remove(_accountsKey);
    print('setting old accounts data - reload app after this');
    await _prefs.setString(_oldAccountsKeyV3, jsonData);
    // await _prefs.setString(_oldAccountsKeyV2, jsonData); // test mid new accts - also works
    // await _prefs.setString(_oldAccountsKeyV1, jsonData);
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

  bool referralCheckCompleted() {
    return _prefs.getBool(hasCheckedReferralKey) ?? false;
  }

  void setReferralCheckCompleted() {
    _prefs.setBool(hasCheckedReferralKey, true);
  }

  void clearReferralCheckCompletedFlag() {
    _prefs.remove(hasCheckedReferralKey);
  }

  String? getReferralCode() {
    return _prefs.getString(referralCodeKey);
  }

  void setReferralCode(String code) {
    _prefs.setString(referralCodeKey, code);
  }

  bool hasWatchedQuestsPromo() {
    return _prefs.getBool(hasWatchedQuestsPromoKey) ?? false;
  }

  void setQuestsPromoWatched() {
    _prefs.setBool(hasWatchedQuestsPromoKey, true);
  }

  void clearQuestsPromoWatchedFlag() {
    _prefs.remove(hasWatchedQuestsPromoKey);
  }

  bool existingUserSeenPromoVideo() {
    return _prefs.getBool(existingUserSeenPromoVideoKey) ?? false;
  }

  void setExistingUserSeenPromoVideo() {
    _prefs.setBool(existingUserSeenPromoVideoKey, true);
  }

  void clearExistingUserSeenPromoVideoFlag() {
    _prefs.remove(existingUserSeenPromoVideoKey);
  }
}
