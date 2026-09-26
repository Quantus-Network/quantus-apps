@Tags(['native'])
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mnemonic =
      'orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await QuantusSdk.init();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({SettingsService().getMnemonicKey(0): mnemonic});
    await SettingsService().initialize();
  });

  Account local(int index, DilithiumScheme scheme) => Account.derived(
    walletIndex: 0,
    index: index,
    name: 'Account ${index + 1}',
    keypair: HdWalletService().keyPairAtIndex(mnemonic, index, scheme),
    derivationPath: HdWalletService.pathForIndex(index, scheme),
  );

  test('a new account uses ML-DSA-87 at the next free index of that scheme', () async {
    await SettingsService().saveAccounts([local(0, DilithiumScheme.mlDsa87), local(1, DilithiumScheme.mlDsa87)]);

    final created = await AccountsService().createNewAccount(walletIndex: 0);

    expect(created.scheme, DilithiumScheme.mlDsa87);
    expect(created.index, 2);
    expect(created.accountId, HdWalletService().keyPairAtIndex(mnemonic, 2, DilithiumScheme.mlDsa87).ss58Address);
  });

  test('a wallet holding only ML-DSA-65 accounts still gets ML-DSA-87 accounts', () async {
    await SettingsService().saveAccounts([local(0, DilithiumScheme.mlDsa65)]);

    final created = await AccountsService().createNewAccount(walletIndex: 0);

    expect(created.scheme, DilithiumScheme.mlDsa87);
    expect(created.index, 0);
    expect(created.derivationPath, HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa87));
  });
}
