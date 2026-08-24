import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/display_account.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  // New keys for multi-account support
  static const String _accountsKey = 'accounts_v5';
  static const String _multisigAccountsKey = 'multisig_accounts_v1';
  static const String _addressBookKey = 'address_book';

  static const String _activeAccountIndexKey = 'active_account_index';
  static const String _activeAccountIdKey = 'active_account_id';
  static const String _activeDisplayAccountKey = 'active_display_account';
  static const String _balanceHiddenKey = 'balance_hidden';
  static const String _currencyFlippedKey = 'currency_flipped';
  static const String _selectedFiatCurrencyKey = 'selected_fiat_currency';
  static const String _selectedAppLocaleKey = 'selected_app_locale';

  // referral status
  static const String hasCheckedReferralKey = 'referral_check';
  static const String referralCodeKey = 'referral_code';
  static const String hasWatchedQuestsPromoKey = 'quests_promo';
  static const String existingUserSeenPromoVideoKey = 'existing_user_seen_promo_video';

  static const _legacyStorage = FlutterSecureStorage(mOptions: MacOsOptions(usesDataProtectionKeychain: false));
  static const _migratedKeychainKey = 'keychain_migrated_to_this_device';
  bool _keychainMigrated = false;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _keychainMigrated = _prefs.getBool(_migratedKeychainKey) == true;
  }

  Future<void> _ensureKeychainMigrated() async {
    if (_keychainMigrated) return;
    _keychainMigrated = true;
    try {
      for (int i = 0; i < 10; i++) {
        final key = getMnemonicKey(i);
        final value = await _legacyStorage.read(key: key);
        if (value != null) {
          await _legacyStorage.delete(key: key);
          await _secureStorage.write(key: key, value: value);
        }
      }
    } catch (_) {}
    await _prefs.setBool(_migratedKeychainKey, true);
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
      final replacement = _preferNonEncrypted(accounts.where((a) => a.accountId != account.accountId));
      await setActiveAccount(RegularAccount(replacement));
    }
    accounts.removeWhere((a) => a.accountId == account.accountId);
    await saveAccounts(accounts);
  }

  /// Picks a replacement active account, avoiding encrypted (wormhole)
  /// accounts unless they are the only option.
  Account _preferNonEncrypted(Iterable<Account> candidates) =>
      candidates.firstWhere((a) => a.accountType != AccountType.encrypted, orElse: () => candidates.first);

  /// Removes an entire wallet: drops all of its accounts and deletes its
  /// mnemonic from secure storage. The primary wallet (index 0) cannot be
  /// removed.
  Future<void> removeWallet(int walletIndex) async {
    if (walletIndex == 0) {
      throw Exception('Cant remove the primary wallet!');
    }
    final accounts = await getAccounts();
    final remaining = accounts.where((a) => a.walletIndex != walletIndex).toList();
    if (remaining.length == accounts.length) {
      throw Exception('Wallet $walletIndex not found');
    }
    if (remaining.isEmpty) {
      throw Exception('Cant remove last wallet!');
    }
    final activeId = await _getActiveAccountId();
    final activeRemoved = accounts.any((a) => a.walletIndex == walletIndex && a.accountId == activeId);
    if (activeRemoved) {
      await setActiveAccount(RegularAccount(_preferNonEncrypted(remaining)));
    }
    await saveAccounts(remaining);
    await deleteMnemonic(walletIndex);
    await _prefs.remove(_walletOriginKey(walletIndex));
    await _prefs.remove(_recoveryPhraseViewedKey(walletIndex));
    await _prefs.remove(_walletNameKey(walletIndex));
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

  /// Returns the lowest non-negative derivation index not currently used by a
  /// (non-encrypted) account in [walletIndex]. Filling the lowest gap first
  /// keeps a wallet's accounts contiguous and deterministic: removing then
  /// re-adding accounts always reproduces the same indices (and therefore the
  /// same addresses) in the same order.
  Future<int> getNextFreeAccountIndex(int walletIndex) async {
    final accounts = await getAccounts();
    final used = accounts
        .where((a) => a.walletIndex == walletIndex && a.index >= 0 && a.accountType != AccountType.encrypted)
        .map((a) => a.index)
        .toSet();
    var index = 0;
    while (used.contains(index)) {
      index++;
    }
    return index;
  }

  // --- Multisig Accounts ---

  Future<List<MultisigAccount>> getMultisigAccounts() async {
    final jsonStr = _prefs.getString(_multisigAccountsKey);
    if (jsonStr == null) return [];
    final decoded = jsonDecode(jsonStr) as List<dynamic>;
    return decoded.map((e) => MultisigAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _saveMultisigAccounts(List<MultisigAccount> accounts) async {
    final jsonData = accounts.map((a) => a.toJson()).toList();
    await _prefs.setString(_multisigAccountsKey, jsonEncode(jsonData));
  }

  Future<void> addMultisigAccount(MultisigAccount account) async {
    final accounts = await getMultisigAccounts();
    if (accounts.any((a) => a.accountId == account.accountId)) {
      throw Exception('Multisig already added');
    }
    accounts.add(account);
    await _saveMultisigAccounts(accounts);
  }

  Future<void> updateMultisigAccount(MultisigAccount account) async {
    final accounts = await getMultisigAccounts();
    final index = accounts.indexWhere((a) => a.accountId == account.accountId);
    if (index != -1) {
      accounts[index] = account;
      await _saveMultisigAccounts(accounts);
    }
  }

  Future<void> removeMultisigAccount(String accountId) async {
    final accounts = await getMultisigAccounts();
    final filtered = accounts.where((a) => a.accountId != accountId).toList();
    if (filtered.length == accounts.length) {
      throw Exception('Multisig not found');
    }
    await _saveMultisigAccounts(filtered);
    final active = await getActiveAccount();
    if (active is MultisigDisplayAccount && active.account.accountId == accountId) {
      final regulars = await getAccounts();
      if (regulars.isNotEmpty) {
        await setActiveAccount(RegularAccount(regulars.first));
      }
    }
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
    await _ensureKeychainMigrated();
    await _secureStorage.write(key: getMnemonicKey(walletIndex), value: mnemonic);
  }

  Future<String?> getMnemonic(int walletIndex) async {
    await _ensureKeychainMigrated();
    return await _secureStorage.read(key: getMnemonicKey(walletIndex));
  }

  Future<void> deleteMnemonic(int walletIndex) async {
    await _secureStorage.delete(key: getMnemonicKey(walletIndex));
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

  // Currency Flip Settings (whether fiat is shown as the primary display)
  Future<void> setCurrencyFlipped(bool flipped) async {
    await _prefs.setBool(_currencyFlippedKey, flipped);
  }

  bool isCurrencyFlipped() {
    return _prefs.getBool(_currencyFlippedKey) ?? false;
  }

  // Selected Fiat Currency Settings
  Future<void> setSelectedFiatCurrency(String currencyCode) async {
    await _prefs.setString(_selectedFiatCurrencyKey, currencyCode);
  }

  Future<void> clearSelectedFiatCurrency() async {
    await _prefs.remove(_selectedFiatCurrencyKey);
  }

  /// Returns the persisted fiat currency code (e.g. "USD"), or null when no
  /// preference has been saved yet (caller should fall back to the default).
  String? getSelectedFiatCurrency() {
    return _prefs.getString(_selectedFiatCurrencyKey);
  }

  // Selected App Locale Settings
  Future<void> setSelectedAppLocale(String languageCode) async {
    await _prefs.setString(_selectedAppLocaleKey, languageCode);
  }

  Future<void> clearSelectedAppLocale() async {
    await _prefs.remove(_selectedAppLocaleKey);
  }

  /// Returns the persisted language code (e.g. "en", "id"), or null when no
  /// preference has been saved yet (caller should fall back to English).
  String? getSelectedAppLocale() {
    return _prefs.getString(_selectedAppLocaleKey);
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
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  /// Set a boolean value in SharedPreferences
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  /// Get a string value from SharedPreferences
  String? getString(String key) {
    return _prefs.getString(key);
  }

  /// Set a string value from SharedPreferences
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
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

  String _recoveryPhraseViewedKey(int walletIndex) => 'recovery_phrase_viewed_$walletIndex';

  bool recoveryPhraseViewed(int walletIndex) {
    return _prefs.getBool(_recoveryPhraseViewedKey(walletIndex)) ?? false;
  }

  void setRecoveryPhraseViewed(int walletIndex) {
    _prefs.setBool(_recoveryPhraseViewedKey(walletIndex), true);
  }

  String _walletOriginKey(int walletIndex) => 'wallet_origin_$walletIndex';

  WalletOrigin? getWalletOrigin(int walletIndex) {
    final value = _prefs.getString(_walletOriginKey(walletIndex));
    return value == null ? null : WalletOrigin.values.asNameMap()[value];
  }

  void setWalletOrigin(int walletIndex, WalletOrigin origin) {
    _prefs.setString(_walletOriginKey(walletIndex), origin.name);
  }

  // Note: the bare legacy key 'wallet_name' (no index suffix) is a pre-v5
  // account name consumed by the migration in [getAccounts]; index 0 must stay
  // suffixed so the two never collide.
  String _walletNameKey(int walletIndex) => 'wallet_name_$walletIndex';

  String? getWalletName(int walletIndex) => _prefs.getString(_walletNameKey(walletIndex));

  Future<void> setWalletName(int walletIndex, String? name) async {
    if (name == null || name.isEmpty) {
      await _prefs.remove(_walletNameKey(walletIndex));
    } else {
      await _prefs.setString(_walletNameKey(walletIndex), name);
    }
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
