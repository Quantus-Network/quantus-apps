import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ss58/ss58.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();
  bool _initialized = false;

  Future<void> initialize() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  // Account Settings
  Future<void> setAccountId(String accountId) async {
    await _ensureInitialized();
    await _prefs.setString('account_id', accountId);
  }

  Future<String?> getAccountId() async {
    await _ensureInitialized();
    final accountId = _prefs.getString('account_id');
    if (accountId != null && accountId.startsWith('5')) {
      final address = Address.decode(accountId);
      final newAddress = Address(prefix: 189, pubkey: address.pubkey);
      await _prefs.setString('account_id', newAddress.encode());
      print('Converting accountId to qz account ${newAddress.encode()}');
      return newAddress.encode();
    }

    return accountId;
  }

  Future<void> clearAccountId() async {
    await _ensureInitialized();
    await _prefs.remove('account_id');
  }

  // Wallet Name Settings
  Future<void> setWalletName(String name) async {
    await _ensureInitialized();
    await _prefs.setString('wallet_name', name);
  }

  Future<String?> getWalletName() async {
    await _ensureInitialized();
    return _prefs.getString('wallet_name');
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

    // TODO remove this at launch
    if (_prefs.getString('mnemonic') != null) {
      debugPrint('mnemonic found in prefs - transferring to secure storage');
      final m = _prefs.getString('mnemonic')!;
      await setMnemonic(m);
      await _prefs.remove('mnemonic');
      return m;
    }

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
