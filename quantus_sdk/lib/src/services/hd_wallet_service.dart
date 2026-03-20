import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class HdWalletService {
  static const _devSeeds = {
    AppConstants.crystalAlice: 0,
    AppConstants.crystalBob: 1,
    AppConstants.crystalCharlie: 2,
  };

  static bool isDevAccount(String mnemonic) => _devSeeds.containsKey(mnemonic);

  Keypair _deriveHDWallet({required String mnemonic, int account = 0, int change = 0, int addressIndex = 0}) {
    final derivationPath = "m/44'/189189'/$account'/$change'/$addressIndex'";
    return crypto.generateDerivedKeypair(mnemonicStr: mnemonic, path: derivationPath);
  }

  Keypair keyPairAtIndex(String mnemonic, int index) {
    final devSeedByte = _devSeeds[mnemonic];
    if (devSeedByte != null) {
      return crypto.generateKeypairFromSeed(seed: List.filled(32, devSeedByte));
    }
    if (index == -1) {
      return crypto.generateKeypair(mnemonicStr: mnemonic);
    }
    return _deriveHDWallet(mnemonic: mnemonic, account: index);
  }
}
