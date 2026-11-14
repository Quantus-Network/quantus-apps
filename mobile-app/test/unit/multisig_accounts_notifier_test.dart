import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

void main() {
  test('adding a multisig account registers its address through PushRegistration', () async {
    final push = FakePushRegistration();
    final container = ProviderContainer(
      overrides: [
        ...testWalletCoreOverrides(pushRegistration: push),
        settingsServiceProvider.overrideWithValue(FakeSettingsService()),
        remoteConfigServiceProvider.overrideWithValue(FakeRemoteConfigService(RemoteConfigModel.defaults)),
      ],
    );
    addTearDown(container.dispose);
    final account = makeMultisigAccount();

    await container.read(multisigAccountsProvider.notifier).add(account);

    expect(push.calls, ['registerAddress(${account.accountId})']);
  });
}
