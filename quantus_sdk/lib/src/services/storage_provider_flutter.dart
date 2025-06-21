import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quantus_sdk/secure_storage_service.dart';
import 'package:quantus_sdk/preferences_storage_service.dart';

class FlutterSecureStorageService implements SecureStorageService {
  final _secureStorage = const FlutterSecureStorage();

  @override
  Future<void> write({required String key, required String value}) {
    return _secureStorage.write(key: key, value: value);
  }

  @override
  Future<String?> read({required String key}) {
    return _secureStorage.read(key: key);
  }

  @override
  Future<void> delete({required String key}) {
    return _secureStorage.delete(key: key);
  }

  @override
  Future<Map<String, String>> readAll() {
    return _secureStorage.readAll();
  }

  @override
  Future<void> deleteAll() {
    return _secureStorage.deleteAll();
  }

  @override
  Future<bool?> getBool(String key) {
    throw UnimplementedError('getBool is not supported by FlutterSecureStorage');
  }

  @override
  Future<void> remove(String key) {
    return _secureStorage.delete(key: key);
  }

  @override
  Future<void> setBool(String key, bool value) {
    throw UnimplementedError('setBool is not supported by FlutterSecureStorage');
  }
}

class FlutterPreferencesService implements PreferencesStorageService {
  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> _init() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    await _init();
    await _prefs.setString(key, value);
  }

  @override
  Future<String?> read({required String key}) async {
    await _init();
    return _prefs.getString(key);
  }

  @override
  Future<void> delete({required String key}) async {
    await _init();
    await _prefs.remove(key);
  }

  @override
  Future<Map<String, String>> readAll() async {
    await _init();
    final keys = _prefs.getKeys();
    final map = <String, String>{};
    for (String key in keys) {
      final value = _prefs.get(key);
      if (value is String) {
        map[key] = value;
      }
    }
    return map;
  }

  @override
  Future<void> deleteAll() async {
    await _init();
    await _prefs.clear();
  }

  @override
  Future<bool?> getBool(String key) async {
    await _init();
    return _prefs.getBool(key);
  }

  @override
  Future<void> remove(String key) async {
    await _init();
    await _prefs.remove(key);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _init();
    await _prefs.setBool(key, value);
  }
}
