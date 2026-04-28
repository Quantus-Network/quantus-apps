import 'package:quantus_sdk/src/services/hd_wallet_service.dart';

typedef MnemonicGetter = Future<String?> Function();

/// Tracks the wormhole rewards key pair derived from the wallet mnemonic.
///
/// Today only the primary address (account=0, change=0, index=0) is tracked.
/// Change addresses for partial withdrawals will be added here later.
class WormholeAddressManager {
  final MnemonicGetter _getMnemonic;
  final HdWalletService _hdWalletService;

  WormholeKeyPair? _primary;

  WormholeAddressManager({required MnemonicGetter getMnemonic, HdWalletService? hdWalletService})
    : _getMnemonic = getMnemonic,
      _hdWalletService = hdWalletService ?? HdWalletService();

  WormholeKeyPair? get primary => _primary;

  Future<void> initialize() async {
    final mnemonic = await _getMnemonic();
    _primary = mnemonic == null ? null : _hdWalletService.deriveWormholeKeyPair(mnemonic: mnemonic);
  }

  void clear() => _primary = null;
}
