import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class HdWalletService {
  static const _devAccounts = {
    AppConstants.crystalAlice: crypto.crystalAlice,
    AppConstants.crystalBob: crypto.crystalBob,
    AppConstants.crystalCharlie: crypto.crystalCharlie,
  };

  static bool isDevAccount(String mnemonic) => _devAccounts.containsKey(mnemonic);

  Keypair _deriveHDWallet({required String mnemonic, int account = 0, int change = 0, int addressIndex = 0}) {
    final derivationPath = "m/44'/189189'/$account'/$change'/$addressIndex'";
    return crypto.generateDerivedKeypair(mnemonicStr: mnemonic, path: derivationPath);
  }

  Keypair keyPairAtIndex(String mnemonic, int index) {
    final devKeypair = _devAccounts[mnemonic];
    if (devKeypair != null) return devKeypair();
    if (index == -1) return crypto.generateKeypair(mnemonicStr: mnemonic);
    return _deriveHDWallet(mnemonic: mnemonic, account: index);
  }
}
