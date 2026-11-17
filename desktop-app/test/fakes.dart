import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_desktop_wallet/providers/boot_intro_provider.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/remote_config_service.dart';

/// The stored settings the shell reads, without the device's storage. A
/// wallet with its recovery phrase is there unless a test says otherwise.
class FakeSettingsService extends Fake implements SettingsService {
  FakeSettingsService({
    this.activeAccount,
    this.multisigs = const [],
    this.walletNames = const {},
    Map<int, String>? mnemonics,
  }) : mnemonics = mnemonics ?? {0: 'a stored recovery phrase'};

  DisplayAccount? activeAccount;
  final List<MultisigAccount> multisigs;
  final Map<int, String> walletNames;
  final Map<int, String> mnemonics;

  /// The flags kept under plain keys. The boot intro counts as seen already,
  /// so it plays only in the tests that are about it.
  final Map<String, bool> bools = {BootIntroSeenNotifier.settingsKey: true};

  @override
  bool? getBool(String key) => bools[key];

  @override
  Future<void> setBool(String key, bool value) async => bools[key] = value;

  @override
  Future<bool> getHasWallet() async => true;

  @override
  Future<String?> getMnemonic(int walletIndex) async => mnemonics[walletIndex];

  @override
  String? pendingAccountScan(int walletIndex) => null;

  @override
  Future<DisplayAccount?> getActiveAccount() async => activeAccount;

  @override
  Future<void> setActiveAccount(DisplayAccount account) async => activeAccount = account;

  @override
  Future<List<MultisigAccount>> getMultisigAccounts() async => multisigs;

  /// The language chosen in Settings.
  String? locale = 'en';

  @override
  String? getSelectedAppLocale() => locale;

  /// When set, saving the language fails with this.
  Object? localeError;

  /// When set, the language is saved (or fails) only once this completes.
  Completer<void>? localeHeld;

  @override
  Future<void> setSelectedAppLocale(String languageCode) async {
    if (localeHeld case final held?) await held.future;
    if (localeError case final error?) throw error;
    locale = languageCode;
  }

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

  /// The shell's wallets come complete: there is nothing to add.
  @override
  Future<bool> ensureEncryptedAccountsForSoftwareWallets({required String name}) async => false;
}

/// A device's wallet storage, kept in memory: what [FakeWalletDevice] reads
/// and writes when a wallet is created, imported or wiped.
class FakeWalletStorage extends FakeSettingsService {
  FakeWalletStorage() : super(mnemonics: {});

  final List<Account> accounts = [];
  final Map<int, WalletOrigin> origins = {};
  final Map<int, String> pendingScans = {};

  /// When set, the check for a wallet waits for this first.
  Future<void>? hasWalletGate;

  /// When set, the check for a wallet fails with this.
  Object? hasWalletError;

  /// How many times the device was asked whether it has a wallet.
  int hasWalletChecks = 0;

  /// When set, saving a recovery phrase fails with this.
  Object? mnemonicWriteError;

  /// When set, deriving a wallet's encrypted account waits for this first.
  Future<void>? encryptedAccountsGate;

  @override
  Future<List<Account>> getAccounts() async => List.of(accounts);

  @override
  Future<bool> getHasWallet() async {
    hasWalletChecks++;
    await hasWalletGate;
    if (hasWalletError case final error?) throw error;
    return accounts.isNotEmpty;
  }

  @override
  Future<void> addAccount(Account account) async {
    if (accounts.any((a) => a.accountId == account.accountId)) throw Exception('Account already exists');
    accounts.add(account);
    if (accounts.length == 1) activeAccount = RegularAccount(account);
  }

  @override
  Future<void> setMnemonic(String mnemonic, int walletIndex) async {
    if (mnemonicWriteError case final error?) throw error;
    mnemonics[walletIndex] = mnemonic;
  }

  @override
  Future<void> deleteMnemonic(int walletIndex) async => mnemonics.remove(walletIndex);

  @override
  WalletOrigin? getWalletOrigin(int walletIndex) => origins[walletIndex];

  @override
  void setWalletOrigin(int walletIndex, WalletOrigin origin) => origins[walletIndex] = origin;

  @override
  String? pendingAccountScan(int walletIndex) => pendingScans[walletIndex];

  @override
  Future<void> setPendingAccountScan(int walletIndex, String? rootAccountId) async {
    if (rootAccountId == null) {
      pendingScans.remove(walletIndex);
    } else {
      pendingScans[walletIndex] = rootAccountId;
    }
  }

  @override
  Future<void> setMainnetMigrationDone() async {}

  @override
  void setReferralCheckCompleted() {}

  @override
  void setExistingUserSeenPromoVideo() {}

  /// The wallets whose recovery phrase has been shown or copied.
  final Set<int> viewedPhrases = {};

  @override
  bool recoveryPhraseViewed(int walletIndex) => viewedPhrases.contains(walletIndex);

  @override
  void setRecoveryPhraseViewed(int walletIndex) => viewedPhrases.add(walletIndex);
}

class _StoredAccountsService extends Fake implements AccountsService {
  _StoredAccountsService(this.storage);

  final FakeWalletStorage storage;

  @override
  Future<List<Account>> getAccounts() => storage.getAccounts();

  @override
  Future<void> addAccount(Account newAccount) => storage.addAccount(newAccount);

  @override
  Future<bool> ensureEncryptedAccountsForSoftwareWallets({required String name}) async {
    await storage.encryptedAccountsGate;
    var created = false;
    for (final walletIndex in storage.accounts.map((a) => a.walletIndex).toSet()) {
      final wallet = storage.accounts.where((a) => a.walletIndex == walletIndex);
      if (wallet.every((a) => a.accountType == AccountType.keystone)) continue;
      if (wallet.any((a) => a.accountType == AccountType.encrypted)) continue;
      await storage.addAccount(
        Account(
          walletIndex: walletIndex,
          index: AppConstants.encryptedAccountIndex,
          name: name,
          accountId: 'qzEncrypted$walletIndex',
          accountType: AccountType.encrypted,
        ),
      );
      created = true;
    }
    return created;
  }
}

/// Key derivation without the Rust library: the "key" is its own address,
/// `qz(<first word of the phrase>)`.
class _FakeHdWalletService extends Fake implements HdWalletService {
  @override
  Keypair keyPairAtPath(String mnemonic, String path, DilithiumScheme scheme) => Keypair(
    publicKey: Uint8List.fromList(utf8.encode('qz(${mnemonic.split(' ').first})')),
    secretKey: Uint8List(0),
    scheme: scheme,
  );

  @override
  String addressOf(Keypair keypair) => utf8.decode(keypair.publicKey);
}

class _FakeSubstrateService extends Fake implements SubstrateService {
  _FakeSubstrateService(this.device);

  final FakeWalletDevice device;

  @override
  Future<String> generateMnemonic() => device.generateMnemonic();
}

class _FakeAccountDiscoveryService extends Fake implements AccountDiscoveryService {
  _FakeAccountDiscoveryService(this.device);

  final FakeWalletDevice device;

  @override
  Future<List<Account>> discoverAccounts({required String mnemonic, required int walletIndex, int gapLimit = 20}) {
    device.scans++;
    return device.scan();
  }
}

class _WipingLogoutService extends Fake implements LogoutService {
  _WipingLogoutService(this.device);

  final FakeWalletDevice device;

  @override
  Future<void> logout() async {
    if (device.logoutError case final error?) throw error;
    device.logouts++;
    device.storage
      ..accounts.clear()
      ..mnemonics.clear()
      ..pendingScans.clear()
      ..bools.clear()
      ..activeAccount = null;
  }
}

/// A device and a chain for the flows that create, import or wipe a wallet.
/// It starts with no wallet. Every balance is one token.
class FakeWalletDevice {
  final storage = FakeWalletStorage();

  /// What generating a recovery phrase answers.
  Future<String> Function() generateMnemonic = () async => 'created wallet recovery phrase';

  /// What the chain scan for a wallet's accounts answers.
  Future<List<Account>> Function() scan = () async => [];

  /// How many chain scans ran, and how many times the wallet was wiped.
  int scans = 0;
  int logouts = 0;

  /// When set, wiping the wallet fails with this.
  Object? logoutError;

  /// Puts a software wallet with [accounts] on the device.
  void store(List<Account> accounts, {String? mnemonic = 'a stored recovery phrase'}) {
    storage.accounts.addAll(accounts);
    storage.activeAccount = RegularAccount(accounts.first);
    if (mnemonic != null) storage.mnemonics[accounts.first.walletIndex] = mnemonic;
  }

  List<Override> get overrides => [
    settingsServiceProvider.overrideWithValue(storage),
    accountsServiceProvider.overrideWithValue(_StoredAccountsService(storage)),
    hdWalletServiceProvider.overrideWithValue(_FakeHdWalletService()),
    substrateServiceProvider.overrideWithValue(_FakeSubstrateService(this)),
    accountDiscoveryServiceProvider.overrideWithValue(_FakeAccountDiscoveryService(this)),
    logoutServiceProvider.overrideWithValue(_WipingLogoutService(this)),
    remoteConfigProvider.overrideWith(
      (ref) => RemoteConfigNotifier(FakeRemoteConfigService(RemoteConfigModel.defaults)),
    ),
    balanceProviderFamily.overrideWith((ref, accountId) => oneToken),
    encryptedBalanceProvider.overrideWith((ref, walletIndex) => AsyncValue.data(oneToken)),
    encryptedStateProvider.overrideWith(
      (ref, walletIndex) => EncryptedAccountState(
        accountId: 'qzEncrypted$walletIndex',
        ownAddresses: const {},
        received: const [],
        spends: const {},
        utxos: const [],
        pendingChangeToken: BigInt.zero,
        nextIndex: 0,
        nextChangeIndex: 0,
      ),
    ),
  ];
}

/// The system's approval, answering as a test says. It approves unless told
/// otherwise.
class FakeUserApproval implements UserApproval {
  ApprovalAvailability availabilityAnswer = ApprovalAvailability.available;

  /// What a request answers; it may throw.
  Future<ApprovalResult> Function() answer = () async => ApprovalResult.approved;

  /// The reason given with each request.
  final reasons = <String>[];

  @override
  Future<ApprovalAvailability> availability() async => availabilityAnswer;

  @override
  Future<ApprovalResult> approve({required String reason}) {
    reasons.add(reason);
    return answer();
  }
}

/// The clipboard for secrets, without the native side.
class FakeSensitiveClipboard extends Fake implements SensitiveClipboard {
  final copied = <String>[];

  /// When set, a copy fails with this.
  Object? error;

  /// When set, a copy is made (or fails) only once this completes.
  Completer<void>? held;

  @override
  Future<void> copy(String text) async {
    if (held case final held?) await held.future;
    if (error case final error?) throw error;
    copied.add(text);
  }

  @override
  void dispose() {}
}

/// Collects what the app asks of its window, in place of the native side.
List<String> recordWindowRequests(WidgetTester tester) {
  final requests = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(WindowChrome.channel, (call) async {
    requests.add(call.method);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(WindowChrome.channel, null));
  return requests;
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
  Future<String> Function(int walletIndex)? depositAddress,
}) {
  return [
    if (depositAddress != null)
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) => FakeEncryptedAccountService(() => depositAddress(walletIndex)),
      ),
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

/// Looks checkphrases up with [lookup] for the rest of the test, in place
/// of the real lookup, which needs the Rust library.
void useFakeCheckphrases(Future<String?> Function(String address) lookup) {
  CheckphraseText.resolveOverride = lookup;
  addTearDown(() => CheckphraseText.resolveOverride = null);
}

/// The checkphrase the tests' lookup gives [address].
Future<String?> fakeCheckphrase(String address) async => 'Phrase-$address';

/// An encrypted account whose next unused deposit address comes from
/// [nextAddress].
class FakeEncryptedAccountService extends Fake implements EncryptedAccountService {
  FakeEncryptedAccountService(this.nextAddress);

  final Future<String> Function() nextAddress;

  @override
  Future<WormholeKeyPair> receiveKeyPair() async =>
      WormholeKeyPair(address: await nextAddress(), addressHex: '', rewardsPreimageHex: '', secretHex: '');
}

/// Pumps the whole app in a window of the size the runners open, and waits for
/// it to settle unless [settle] is false (a loader never settles).
///
/// The system asks for reduced motion unless [reduceMotion] is false: the
/// Welcome page's moving background never settles either, so only the tests
/// about that motion turn it on.
Future<void> pumpShell(
  WidgetTester tester, {
  required List<Override> overrides,
  bool settle = true,
  bool reduceMotion = true,
}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  useFakeCheckphrases(fakeCheckphrase);

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
