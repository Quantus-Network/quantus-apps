import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_cold_wallet/models/held_account.dart';

/// Keeps a sealed wallet's public account list in a plain keychain entry.
/// It is deliberately not in the passcode-only class the phrase is sealed in:
/// when iOS destroys the phrase, this survives to say which accounts a
/// restored phrase has to bring back.
class HeldAccountStore {
  static const _key = 'cold_held_accounts';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device, synchronizable: false),
  );

  Future<HeldAccounts?> read() async {
    final text = await _storage.read(key: _key);
    return text == null ? null : HeldAccounts.decode(text);
  }

  Future<void> write(HeldAccounts accounts) => _storage.write(key: _key, value: accounts.encode());

  Future<void> delete() => _storage.delete(key: _key);
}
