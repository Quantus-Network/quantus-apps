import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

// We define the following 5 levels in BIP32 path:
// m / 44' / coin_type' / account' / change / address_index

// Bip44 describes account discovery from seed phrase - it keeps looking by increasing acocunt index, for accounts with activity.
// It defines the max allowed account gap as 20, if there's 20 addresses in a row where there's no activity, it assumes the highest index has been reached.

/// Hierarchical deterministic wallet service.
///
class HdWalletService {
  Keypair _deriveHDWallet({required String mnemonic, int account = 0, int change = 0, int addressIndex = 0}) {
    // m/44'/189189'/0'/0/0
    final derivationPath = "m/44'/189189'/$account'/$change/$addressIndex";
    print('derivationPath: $derivationPath');
    final derivedSeed = crypto.generateDerivedKeypair(mnemonicStr: mnemonic, path: derivationPath);
    return derivedSeed;
  }

  Keypair keyPairAtIndex(String mnemonic, int index) {
    final keypair = _deriveHDWallet(mnemonic: mnemonic, account: index);
    return keypair;
  }
}
