import 'package:quantus_sdk/quantus_sdk.dart';

extension HDWalletAccount on Account {
  Future<Keypair> getKeypair() async {
    final mnemonic = await getMnemonic();
    return HdWalletService().keyPairAtIndex(mnemonic!, index);
  }

  Future<String?> getMnemonic() async {
    return SettingsService().getMnemonic();
  }
}
