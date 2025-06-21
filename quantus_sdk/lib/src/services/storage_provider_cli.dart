import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:encrypt/encrypt.dart' as enc;
import 'secure_storage_service.dart';
import 'preferences_storage_service.dart';

class CliSecureStorageService implements SecureStorageService {
  File? _file;
  enc.Encrypter? _encrypter;
  enc.IV? _iv;

  Future<void> _init() async {
    if (_file != null && _encrypter != null) return;

    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw Exception('Could not find home directory');
    }

    final ivFile = File(p.join(home, '.resonance_cli_encryption.iv'));
    if (await ivFile.exists()) {
      _iv = enc.IV.fromBase64(await ivFile.readAsString());
    } else {
      _iv = enc.IV.fromSecureRandom(16);
      await ivFile.writeAsString(_iv!.base64);
    }

    final keyFile = File(p.join(home, '.resonance_cli_encryption.key'));
    String keyString;
    if (await keyFile.exists()) {
      keyString = await keyFile.readAsString();
    } else {
      keyString = enc.Key.fromSecureRandom(32).base64;
      await keyFile.writeAsString(keyString);
    }

    final key = enc.Key.fromBase64(keyString);
    _encrypter = enc.Encrypter(enc.AES(key));

    final filePath = p.join(home, '.resonance_cli_secure_storage.json');
    _file = File(filePath);
    if (!await _file!.exists()) {
      await _file!.create(recursive: true);
      final encrypted = _encrypter!.encrypt('{}', iv: _iv);
      await _file!.writeAsString(encrypted.base64);
    }
  }

  Future<Map<String, String>> _readData() async {
    await _init();
    final content = await _file!.readAsString();
    if (content.isEmpty) return {};
    final decrypted = _encrypter!.decrypt64(content, iv: _iv);
    return Map<String, String>.from(json.decode(decrypted));
  }

  Future<void> _writeData(Map<String, String> data) async {
    await _init();
    final encrypted = _encrypter!.encrypt(json.encode(data), iv: _iv);
    await _file!.writeAsString(encrypted.base64);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final data = await _readData();
    data[key] = value;
    await _writeData(data);
  }

  @override
  Future<String?> read({required String key}) async {
    try {
      final data = await _readData();
      return data[key];
    } catch (e) {
      // It might fail if the file is empty or corrupted
      return null;
    }
  }

  @override
  Future<void> delete({required String key}) async {
    final data = await _readData();
    data.remove(key);
    await _writeData(data);
  }

  @override
  Future<Map<String, String>> readAll() async {
    try {
      return await _readData();
    } catch (e) {
      return {};
    }
  }

  @override
  Future<void> deleteAll() async {
    await _writeData({});
  }

  @override
  Future<bool?> getBool(String key) {
    throw UnimplementedError('getBool is not supported by secure storage');
  }

  @override
  Future<void> remove(String key) {
    return delete(key: key);
  }

  @override
  Future<void> setBool(String key, bool value) {
    throw UnimplementedError('setBool is not supported by secure storage');
  }
}

class CliPreferencesService implements PreferencesStorageService {
  File? _file;

  Future<File> get _storageFile async {
    if (_file != null) return _file!;
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) {
      throw Exception('Could not find home directory');
    }
    final filePath = p.join(home, '.resonance_cli_prefs.json');
    _file = File(filePath);
    if (!await _file!.exists()) {
      await _file!.create(recursive: true);
      await _file!.writeAsString('{}');
    }
    return _file!;
  }

  Future<Map<String, dynamic>> _readData() async {
    final file = await _storageFile;
    final content = await file.readAsString();
    if (content.isEmpty) return {};
    return Map<String, dynamic>.from(json.decode(content));
  }

  Future<void> _writeData(Map<String, dynamic> data) async {
    final file = await _storageFile;
    await file.writeAsString(json.encode(data));
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final data = await _readData();
    data[key] = value;
    await _writeData(data);
  }

  @override
  Future<String?> read({required String key}) async {
    final data = await _readData();
    return data[key] as String?;
  }

  @override
  Future<void> delete({required String key}) async {
    final data = await _readData();
    data.remove(key);
    await _writeData(data);
  }

  @override
  Future<Map<String, String>> readAll() async {
    final data = await _readData();
    return data.map((key, value) => MapEntry(key, value.toString()));
  }

  @override
  Future<void> deleteAll() async {
    await _writeData({});
  }

  @override
  Future<bool?> getBool(String key) async {
    final data = await _readData();
    return data[key] as bool?;
  }

  @override
  Future<void> remove(String key) async {
    final data = await _readData();
    data.remove(key);
    await _writeData(data);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    final data = await _readData();
    data[key] = value;
    await _writeData(data);
  }
}
