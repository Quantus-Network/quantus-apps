import 'dart:convert';

import 'package:quantus_sdk/src/rust/api/crypto.dart' show WormholeAddresses;
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/settings_service.dart';
import 'package:quantus_sdk/src/utils/app_support_files.dart';
import 'package:quantus_sdk/src/utils/print.dart';

typedef WalletMnemonicGetter = Future<String?> Function(int walletIndex);

/// Wormhole addresses of every software wallet, derived once and kept on disk
/// so discovery, receive addresses and self-send checks never touch the seed.
/// Addresses are public; the secrets behind them are re-derived on demand.
class WormholeAddressBook {
  static const int batchSize = 300;
  static const _filePrefix = 'wormhole_addresses_w';

  static final WormholeAddressBook _instance = WormholeAddressBook.withDependencies(
    getMnemonic: (walletIndex) => SettingsService().getMnemonic(walletIndex),
  );

  factory WormholeAddressBook() => _instance;

  WormholeAddressBook.withDependencies({required WalletMnemonicGetter getMnemonic, HdWalletService? hdWalletService})
    : _getMnemonic = getMnemonic,
      _hdWallet = hdWalletService ?? HdWalletService();

  final WalletMnemonicGetter _getMnemonic;
  final HdWalletService _hdWallet;
  final Map<int, WormholeAddresses> _books = {};

  static String _fileName(int walletIndex) => '$_filePrefix$walletIndex.json';

  Future<void> build(int walletIndex, String mnemonic, {int count = batchSize}) async {
    final book = await _hdWallet.deriveWormholeAddresses(mnemonic, count: count);
    final file = await appSupportFile(_fileName(walletIndex));
    await file.writeAsString(jsonEncode({'external': book.external_, 'change': book.change}));
    _books[walletIndex] = book;
    quantusPrint('[WormholeAddressBook] wallet $walletIndex: $count addresses per branch');
  }

  Future<bool> exists(int walletIndex) async => (await appSupportFile(_fileName(walletIndex))).exists();

  Future<void> ensureBuilt(int walletIndex, String mnemonic) async {
    if (!await exists(walletIndex)) await build(walletIndex, mnemonic);
  }

  /// The address at [index]; extends the book (a seed read) when [index] lies
  /// past it.
  Future<String> addressAt(int walletIndex, int index, {bool isChange = false}) async {
    var book = await _book(walletIndex);
    if (index >= book.external_.length) {
      await build(walletIndex, await _mnemonic(walletIndex), count: (index ~/ batchSize + 1) * batchSize);
      book = _books[walletIndex]!;
    }
    return (isChange ? book.change : book.external_)[index];
  }

  Future<bool> owns(int walletIndex, String address) async {
    final book = await _book(walletIndex);
    return book.external_.contains(address) || book.change.contains(address);
  }

  Future<void> delete(int walletIndex) async {
    _books.remove(walletIndex);
    final file = await appSupportFile(_fileName(walletIndex));
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteAll() async {
    _books.clear();
    final deleted = await deleteAppSupportFiles((name) => name.startsWith(_filePrefix) && name.endsWith('.json'));
    quantusPrint('[WormholeAddressBook] deleteAll: deleted $deleted file(s)');
  }

  Future<WormholeAddresses> _book(int walletIndex) async {
    final cached = _books[walletIndex];
    if (cached != null) return cached;
    final file = await appSupportFile(_fileName(walletIndex));
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return _books[walletIndex] = WormholeAddresses(
        external_: (json['external'] as List).cast<String>(),
        change: (json['change'] as List).cast<String>(),
      );
    }
    await build(walletIndex, await _mnemonic(walletIndex));
    return _books[walletIndex]!;
  }

  Future<String> _mnemonic(int walletIndex) async {
    final mnemonic = await _getMnemonic(walletIndex);
    if (mnemonic == null) throw StateError('No mnemonic for wallet $walletIndex');
    return mnemonic;
  }
}
