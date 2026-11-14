import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_core_overrides.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/remote_config_service.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/models/notification_models.dart';

/// What a device stores about its wallets, kept in memory.
class FakeSettingsService extends Fake implements SettingsService {
  final List<Account> accounts = [];
  final Map<int, String> mnemonics = {};
  final Map<int, WalletOrigin> origins = {};
  final Map<int, String> pendingScans = {};
  DisplayAccount? activeAccount;
  bool migrationDone = false;
  bool referralChecked = false;
  bool seenPromoVideo = false;

  @override
  Future<List<Account>> getAccounts() async => List.of(accounts);

  @override
  Future<bool> getHasWallet() async => accounts.isNotEmpty;

  @override
  Future<void> addAccount(Account account) async {
    if (accounts.any((a) => a.accountId == account.accountId)) throw Exception('Account already exists');
    accounts.add(account);
    if (accounts.length == 1) activeAccount = RegularAccount(account);
  }

  @override
  Future<void> setMnemonic(String mnemonic, int walletIndex) async => mnemonics[walletIndex] = mnemonic;

  @override
  Future<String?> getMnemonic(int walletIndex) async => mnemonics[walletIndex];

  @override
  Future<void> deleteMnemonic(int walletIndex) async => mnemonics.remove(walletIndex);

  @override
  Future<DisplayAccount?> getActiveAccount() async => activeAccount;

  @override
  Future<void> setActiveAccount(DisplayAccount account) async => activeAccount = account;

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
  bool isMainnetMigrationDone() => migrationDone;

  @override
  Future<void> setMainnetMigrationDone() async => migrationDone = true;

  @override
  void setReferralCheckCompleted() => referralChecked = true;

  @override
  void setExistingUserSeenPromoVideo() => seenPromoVideo = true;

  @override
  bool recoveryPhraseViewed(int walletIndex) => false;

  @override
  String? getSelectedAppLocale() => 'en';
}

/// The accounts of [settings], plus the encrypted account the real service
/// derives for a software wallet.
class FakeAccountsService extends Fake implements AccountsService {
  FakeAccountsService(this.settings);

  final FakeSettingsService settings;

  /// When set, deriving the encrypted accounts waits for this first.
  Future<void>? encryptedAccountsGate;

  @override
  Future<List<Account>> getAccounts() => settings.getAccounts();

  @override
  Future<void> addAccount(Account newAccount) => settings.addAccount(newAccount);

  @override
  Future<bool> ensureEncryptedAccountsForSoftwareWallets({required String name}) async {
    await encryptedAccountsGate;
    var created = false;
    for (final walletIndex in settings.accounts.map((a) => a.walletIndex).toSet()) {
      final wallet = settings.accounts.where((a) => a.walletIndex == walletIndex);
      if (wallet.every((a) => a.accountType == AccountType.keystone)) continue;
      if (wallet.any((a) => a.accountType == AccountType.encrypted)) continue;
      await settings.addAccount(
        Account(
          walletIndex: walletIndex,
          index: AppConstants.encryptedAccountIndex,
          name: name,
          accountId: encryptedAddress(walletIndex),
          accountType: AccountType.encrypted,
        ),
      );
      created = true;
    }
    return created;
  }
}

/// The address [FakeAccountsService] gives a wallet's encrypted account.
String encryptedAddress(int walletIndex) => 'qzEncrypted$walletIndex';

/// The address [FakeHdWalletService] derives for [mnemonic] at [path].
String derivedAddress(String mnemonic, String path) => 'qz(${mnemonic.split(' ').first} $path)';

/// Key derivation without the Rust library: the "key" is its own address.
class FakeHdWalletService extends Fake implements HdWalletService {
  @override
  Keypair keyPairAtPath(String mnemonic, String path, DilithiumScheme scheme) => Keypair(
    publicKey: Uint8List.fromList(utf8.encode(derivedAddress(mnemonic, path))),
    secretKey: Uint8List(0),
    scheme: scheme,
  );

  @override
  String addressOf(Keypair keypair) => utf8.decode(keypair.publicKey);
}

class FakeSubstrateService extends Fake implements SubstrateService {
  FakeSubstrateService({required this.mnemonic});

  /// What [generateMnemonic] answers.
  String mnemonic;

  @override
  Future<String> generateMnemonic() async => mnemonic;
}

/// The chain scan for a wallet's accounts. Each call takes the next entry of
/// [scans]; the last one repeats.
class FakeAccountDiscoveryService extends Fake implements AccountDiscoveryService {
  FakeAccountDiscoveryService(this.scans);

  final List<Future<List<Account>> Function()> scans;
  int calls = 0;

  @override
  Future<List<Account>> discoverAccounts({required String mnemonic, required int walletIndex, int gapLimit = 20}) {
    final scan = scans[calls < scans.length ? calls : scans.length - 1];
    calls++;
    return scan();
  }
}

class FakeTelemetry implements Telemetry {
  final List<String> events = [];
  final List<String> errors = [];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) => events.add(eventName);

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

class FakePushRegistration implements PushRegistration {
  int deviceRegistrations = 0;
  final List<String> registeredAddresses = [];

  @override
  Future<void> registerDevice() async => deviceRegistrations++;

  @override
  Future<void> registerAddress(String address) async => registeredAddresses.add(address);

  @override
  Future<void> unregister() async {}
}

class _NoLocalNotifications implements LocalNotifications {
  @override
  Future<void> showOrScheduleNotification(NotificationData notification) async {}
}

class _FixedRemoteConfigService extends RemoteConfigService {
  _FixedRemoteConfigService(this.config);

  final RemoteConfigModel config;

  @override
  RemoteConfigModel readLocalConfig() => config;

  @override
  Future<RemoteConfigModel?> readRemoteConfig() async => null;

  @override
  Future<void> cacheConfig(Object json) async {}
}

/// A device with no wallet, and a chain that answers what the test says.
class WalletTestBed {
  WalletTestBed({String generatedMnemonic = '', List<Future<List<Account>> Function()>? scans})
    : substrate = FakeSubstrateService(mnemonic: generatedMnemonic),
      discovery = FakeAccountDiscoveryService(scans ?? [() async => []]);

  final settings = FakeSettingsService();
  late final accounts = FakeAccountsService(settings);
  final hdWallet = FakeHdWalletService();
  final telemetry = FakeTelemetry();
  final pushRegistration = FakePushRegistration();
  final FakeSubstrateService substrate;
  final FakeAccountDiscoveryService discovery;

  /// The wallets whose encrypted state was loaded.
  final List<int> encryptedStatesLoaded = [];

  List<Override> get overrides => [
    ...walletCoreOverrides(
      telemetry: (_) => telemetry,
      pushRegistration: (_) => pushRegistration,
      localNotifications: (_) => _NoLocalNotifications(),
    ),
    settingsServiceProvider.overrideWithValue(settings),
    accountsServiceProvider.overrideWithValue(accounts),
    hdWalletServiceProvider.overrideWithValue(hdWallet),
    substrateServiceProvider.overrideWithValue(substrate),
    accountDiscoveryServiceProvider.overrideWithValue(discovery),
    remoteConfigProvider.overrideWith(
      (ref) => RemoteConfigNotifier(_FixedRemoteConfigService(RemoteConfigModel.defaults)),
    ),
    encryptedStateProvider.overrideWith((ref, walletIndex) {
      encryptedStatesLoaded.add(walletIndex);
      return EncryptedAccountState(
        accountId: encryptedAddress(walletIndex),
        ownAddresses: const {},
        received: const [],
        spends: const {},
        utxos: const [],
        pendingChangeToken: BigInt.zero,
        nextIndex: 0,
        nextChangeIndex: 0,
      );
    }),
  ];
}

/// Pumps a widget over [overrides] and hands back its ref, for functions that
/// take a [WidgetRef].
Future<WidgetRef> pumpRef(WidgetTester tester, {required List<Override> overrides}) async {
  late WidgetRef ref;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, widgetRef, _) {
          ref = widgetRef;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return ref;
}
