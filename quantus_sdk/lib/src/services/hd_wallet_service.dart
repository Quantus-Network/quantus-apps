import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

// We define the following 5 levels in BIP32 path:
// m / purpose' / coin_type' / account' / change / address_index
// For Quantus purpose should be 189 or if that's not available maybe 1899
// coin type should be 0 for native
// account is the account index - 1, 2, 3...
// change and address index should remain at 0

// Bip44 describes account discovery from seed phrase - it keeps looking by increasing acocunt index, for accounts with activity.
// It defines the max allowed account gap as 20, if there's 20 addresses in a row where there's no activity, it assumes the highest index has been reached.

/// Hierarchical deterministic wallet service.
///
class HdWalletService {
  Uint8List _deriveHDWallet({
    required Uint8List seed,
    int purpose = 189189,
    int coinType = 0,
    int account = 0,
    int change = 0,
    int addressIndex = 0,
  }) {
    final derivationPath = "//$purpose'//$coinType'//$account'//$change//$addressIndex";
    final derivedSeed = crypto.deriveHdPath(seed: seed, path: derivationPath);
    return derivedSeed;
  }

  Uint8List _derivedSeedAtIndex(Uint8List seed, int index, {int coinType = 0}) {
    return _deriveHDWallet(seed: seed, account: index, coinType: coinType);
  }

  Keypair keyPairAtIndex(String mnemonic, int index) {
    // Derive the new keypair
    final seed = crypto.seedFromMnemonic(mnemonicStr: mnemonic);

    var seedToUse = seed;

    if (index != 0) {
      // HD derivation
      seedToUse = HdWalletService()._derivedSeedAtIndex(seed, index);
    }

    // We use this private key as seed to derive a new Dilithium pair.
    final keypair = crypto.generateKeypairFromSeed(seed: seedToUse);

    return keypair;
  }
}
