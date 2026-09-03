import 'package:quantus_sdk/quantus_sdk.dart';

extension HDWalletAccount on Account {
  Future<Keypair> getKeypair() async {
    final path = derivationPath;
    final keyScheme = scheme;
    if (path == null || keyScheme == null) {
      throw StateError('Account $accountId (${accountType.name}) holds no local key');
    }
    final mnemonic = await getMnemonic();
    if (mnemonic == null) throw StateError('Mnemonic not found for wallet $walletIndex');
    return HdWalletService().keyPairAtPath(mnemonic, path, keyScheme);
  }

  Future<String?> getMnemonic() {
    return SettingsService().getMnemonic(walletIndex);
  }
}
