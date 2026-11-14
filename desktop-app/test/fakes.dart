import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/remote_config_service.dart';

/// The stored settings the shell reads, without the device's storage.
class FakeSettingsService extends Fake implements SettingsService {
  FakeSettingsService({this.activeAccount, this.multisigs = const [], this.walletNames = const {}});

  DisplayAccount? activeAccount;
  final List<MultisigAccount> multisigs;
  final Map<int, String> walletNames;

  @override
  Future<DisplayAccount?> getActiveAccount() async => activeAccount;

  @override
  Future<void> setActiveAccount(DisplayAccount account) async => activeAccount = account;

  @override
  Future<List<MultisigAccount>> getMultisigAccounts() async => multisigs;

  @override
  String? getSelectedAppLocale() => 'en';

  @override
  String? getWalletName(int walletIndex) => walletNames[walletIndex];

  @override
  ActiveSwap? getActiveSwap() => null;
}

class FakeAccountsService extends Fake implements AccountsService {
  FakeAccountsService(this.load);

  final Future<List<Account>> Function() load;

  @override
  Future<List<Account>> getAccounts() => load();
}

class FakeRemoteConfigService extends RemoteConfigService {
  FakeRemoteConfigService(this.config);

  final RemoteConfigModel config;

  @override
  RemoteConfigModel readLocalConfig() => config;

  @override
  Future<RemoteConfigModel?> readRemoteConfig() async => null;

  @override
  Future<void> cacheConfig(Object json) async {}
}

const _swapsNotOffered = RemoteConfigModel(
  enableTestButtons: false,
  enableKeystoneHardwareWallet: true,
  enableHighSecurity: false,
  enableRemoteNotifications: true,
  enableEncryptedAccount: true,
  enableMultisig: true,
  enableOneClickNearWarning: true,
  geoNearAllowed: false,
);

/// Stands in for everything the shell reads from the device and the chain.
///
/// A balance missing from [balances] or [encryptedBalances] fails to load.
/// [loadAccounts] and [balanceOf] replace the plain lists for tests that need
/// a load to hang or fail.
List<Override> shellOverrides({
  List<Account> accounts = const [],
  Future<List<Account>> Function()? loadAccounts,
  FakeSettingsService? settings,
  Map<String, BigInt> balances = const {},
  Future<BigInt> Function(String accountId)? balanceOf,
  Map<int, BigInt> encryptedBalances = const {},
  bool swapAvailable = true,
}) {
  return [
    settingsServiceProvider.overrideWithValue(settings ?? FakeSettingsService()),
    accountsServiceProvider.overrideWithValue(FakeAccountsService(loadAccounts ?? () async => accounts)),
    remoteConfigProvider.overrideWith(
      (ref) =>
          RemoteConfigNotifier(FakeRemoteConfigService(swapAvailable ? RemoteConfigModel.defaults : _swapsNotOffered)),
    ),
    balanceProviderFamily.overrideWith((ref, accountId) {
      if (balanceOf != null) return balanceOf(accountId);
      final balance = balances[accountId];
      if (balance == null) throw StateError('no balance set for $accountId');
      return balance;
    }),
    encryptedBalanceProvider.overrideWith((ref, walletIndex) {
      final balance = encryptedBalances[walletIndex];
      if (balance == null) {
        return AsyncValue.error(StateError('no encrypted balance set for wallet $walletIndex'), StackTrace.current);
      }
      return AsyncValue.data(balance);
    }),
  ];
}

/// Pumps the whole app in a window of the size the runners open, and waits for
/// it to settle unless [settle] is false (a loader never settles).
Future<void> pumpShell(WidgetTester tester, {required List<Override> overrides, bool settle = true}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(buildApp(overrides: overrides));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// A widget test run as the macOS app: the menu bar is native there, so the
/// window holds only the sidebar and the pane.
void testOnMac(String description, WidgetTesterCallback body) {
  testWidgets(description, body, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

/// A widget test run once as the Windows app and once as the Linux app.
void testOnWindowsAndLinux(String description, WidgetTesterCallback body) {
  testWidgets(description, body, variant: const TargetPlatformVariant({TargetPlatform.windows, TargetPlatform.linux}));
}

/// One whole token, in the chain's smallest unit.
final BigInt oneToken = BigInt.from(10).pow(AppConstants.decimals);

const mainAccount = Account(walletIndex: 0, index: 0, name: 'Main', accountId: 'qzMain');
const savingsAccount = Account(walletIndex: 0, index: 1, name: 'Savings', accountId: 'qzSavings');
const encryptedAccount = Account(
  walletIndex: 0,
  index: 0,
  name: 'Encrypted Account',
  accountId: 'qzEncrypted',
  accountType: AccountType.encrypted,
);
const tradingAccount = Account(walletIndex: 2, index: 0, name: 'Trading', accountId: 'qzTrading');
const vaultAccount = Account(
  walletIndex: 1,
  index: 0,
  name: 'Vault',
  accountId: 'qzVault',
  accountType: AccountType.keystone,
);

final teamMultisig = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzMain', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);
final orphanMultisig = MultisigAccount(
  name: 'Orphan',
  accountId: 'qzOrphan',
  signers: const ['qzGone', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzGone',
);

/// A balance of one token for every account above.
final Map<String, BigInt> oneTokenEach = {
  for (final id in ['qzMain', 'qzSavings', 'qzTrading', 'qzVault', 'qzTeam', 'qzOrphan']) id: oneToken,
};
