import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_core_overrides.dart';
import 'package:wallet_core/services/wallet_session.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/remote_config_service.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/models/notification_models.dart';

/// What a device stores about its wallets, kept in memory.
class FakeSettingsService extends Fake implements SettingsService {
  final List<Account> accounts = [];
  final Map<int, String> mnemonics = {};
  final Map<int, WalletOrigin> origins = {};
  final Map<int, String> pendingScans = {};
  DisplayAccount? activeAccount;

  /// The swaps being followed, as the device keeps them.
  final List<ActiveSwap> activeSwaps = [];
  bool migrationDone = false;
  bool referralChecked = false;
  bool seenPromoVideo = false;

  /// When set, saving an account fails with this.
  Object? addAccountError;

  @override
  Future<List<Account>> getAccounts() async => List.of(accounts);

  @override
  Future<bool> getHasWallet() async => accounts.isNotEmpty;

  @override
  Future<void> addAccount(Account account) async {
    final error = addAccountError;
    if (error != null) throw error;
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

  @override
  Future<void> clearSelectedAppLocale() async {}

  @override
  String? getSelectedFiatCurrency() => null;

  @override
  Future<void> clearSelectedFiatCurrency() async {}

  @override
  List<ActiveSwap> getActiveSwaps() => [...activeSwaps];

  @override
  Future<void> saveActiveSwap(ActiveSwap swap) async {
    final at = activeSwaps.indexWhere((s) => s.id == swap.id);
    if (at < 0) {
      activeSwaps.add(swap);
    } else {
      activeSwaps[at] = swap;
    }
  }

  @override
  Future<void> removeActiveSwap(String id) async => activeSwaps.removeWhere((s) => s.id == id);

  @override
  Future<void> clearActiveSwaps() async => activeSwaps.clear();

  @override
  Future<List<MultisigAccount>> getMultisigAccounts() async => const [];

  /// The multisigs saved since the test began.
  final savedMultisigs = <MultisigAccount>[];

  /// When set, a save is recorded and then answers only once this completes.
  Completer<void>? holdMultisigSave;

  /// When set, a save stores nothing and fails with this, after
  /// [holdMultisigSave].
  Object? addMultisigError;

  @override
  Future<void> addMultisigAccount(MultisigAccount account) async {
    final error = addMultisigError;
    if (error == null) savedMultisigs.add(account);
    await holdMultisigSave?.future;
    if (error != null) throw error;
  }
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

  /// When set, wiping the wallet fails with this.
  Object? logoutError;

  /// When set, signing waits for it.
  Completer<void>? holdSigning;

  /// The signed extrinsics broadcast.
  final broadcast = <Uint8List>[];

  @override
  Future<String> generateMnemonic() async => mnemonic;

  @override
  Future<ExtrinsicData> getExtrinsicPayload(Account account, RuntimeCall call, {bool isSigned = true}) async {
    await holdSigning?.future;
    return ExtrinsicData(payload: Uint8List.fromList([1]), blockHash: '0xblock', blockNumber: 1, nonce: 0);
  }

  @override
  Future<Uint8List> submitSignedExtrinsic(Uint8List extrinsic, {int maxRetries = 3}) async {
    broadcast.add(extrinsic);
    return Uint8List.fromList([1]);
  }

  /// When set, a broadcast signed off-device answers with what this completes
  /// with.
  Completer<Uint8List>? holdExternalBroadcast;

  @override
  Future<Uint8List> submitExtrinsicWithExternalSignature(
    UnsignedTransactionData unsignedData,
    Uint8List signatureWithPublicKey,
  ) async => await holdExternalBroadcast?.future ?? Uint8List.fromList([1]);

  /// When set, the wipe waits for it: after clearing the preferences, as the
  /// real one then goes on to the keychain and the files, or before failing
  /// with [logoutError].
  Completer<void>? holdWipe;

  /// Clears the saved preferences, as the real wipe does.
  @override
  Future<void> logout() async {
    if (logoutError case final error?) {
      await holdWipe?.future;
      throw error;
    }
    await (await SharedPreferences.getInstance()).clear();
    await holdWipe?.future;
  }
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

  /// When set, an address is recorded and then answers only once this completes.
  Completer<void>? holdAddress;

  @override
  Future<void> registerAddress(String address) async {
    registeredAddresses.add(address);
    await holdAddress?.future;
  }

  @override
  Future<void> unregister() async {}
}

/// The device's approval, answering as a test says. It approves unless told
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

/// The system's notifications: notes what is shown or scheduled and what is
/// cancelled, and fails to cancel when told to.
class FakeLocalNotifications implements LocalNotifications {
  final shown = <NotificationData>[];
  int cancelAllCalls = 0;
  Object? cancelAllError;

  /// When set, cancelling waits for it, as a platform call does.
  Completer<void>? holdCancel;

  @override
  Future<void> showOrScheduleNotification(NotificationData notification) async => shown.add(notification);

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    await holdCancel?.future;
    if (cancelAllError case final error?) throw error;
  }
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
  /// [storage], when given, is the settings service the app uses in place
  /// of [settings].
  WalletTestBed({String generatedMnemonic = '', List<Future<List<Account>> Function()>? scans, this.storage})
    : substrate = FakeSubstrateService(mnemonic: generatedMnemonic),
      discovery = FakeAccountDiscoveryService(scans ?? [() async => []]);

  final settings = FakeSettingsService();
  final SettingsService? storage;
  late final accounts = FakeAccountsService(settings);
  final hdWallet = FakeHdWalletService();
  final telemetry = FakeTelemetry();
  final pushRegistration = FakePushRegistration();
  final localNotifications = FakeLocalNotifications();
  final userApproval = FakeUserApproval();
  final FakeSubstrateService substrate;
  final FakeAccountDiscoveryService discovery;

  /// The wallets whose encrypted state was loaded.
  final List<int> encryptedStatesLoaded = [];

  /// What the wallet session logged as dropped by a reset.
  final droppedByReset = <String>[];
  late final walletSession = WalletSession(log: droppedByReset.add);

  List<Override> get overrides => [
    walletSessionProvider.overrideWithValue(walletSession),
    ...walletCoreOverrides(
      telemetry: (_) => telemetry,
      pushRegistration: (_) => pushRegistration,
      localNotifications: (_) => localNotifications,
      userApproval: (_) => userApproval,
    ),
    settingsServiceProvider.overrideWithValue(storage ?? settings),
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

/// Builds [build] in a widget over [overrides], for functions that watch
/// providers, and hands back a way to read what the latest build returned.
Future<T Function()> pumpWatched<T>(
  WidgetTester tester, {
  required List<Override> overrides,
  required T Function(WidgetRef ref) build,
}) async {
  late T latest;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) {
          latest = build(ref);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return () => latest;
}

/// An account of the first wallet, signing in this app unless [accountType]
/// says otherwise.
Account makeAccount(int index, {AccountType accountType = AccountType.local}) => Account(
  walletIndex: 0,
  index: index,
  name: 'Account $index',
  accountId: 'qzaccount$index${'x' * 40}',
  accountType: accountType,
);

/// Builds the transfer calls without the chain's address decoding.
class FakeBalancesService extends Fake implements BalancesService {
  static final _anyDest = const multi_address.$MultiAddress().id(List<int>.filled(32, 0));

  @override
  Balances getBalanceTransferCall(String targetAddress, BigInt amount) =>
      const balances_pallet.Txs().transferAllowDeath(dest: _anyDest, value: amount);

  @override
  Balances getTransferAllCall(String targetAddress) =>
      const balances_pallet.Txs().transferAll(dest: _anyDest, keepAlive: false);
}

/// A transaction as a hardware device would be handed it.
UnsignedTransactionData makeUnsignedTransactionData() => UnsignedTransactionData(
  payloadToSign: QuantusSigningPayload(
    method: Uint8List(0),
    specVersion: 1,
    transactionVersion: 1,
    genesisHash: '0x00',
    blockHash: '0x00',
    blockNumber: 42,
    eraPeriod: 64,
    nonce: 0,
    tip: 0,
  ),
  signer: Uint8List(32),
  registry: Object(),
);

/// Records what would be signed and submitted instead of doing it.
class FakeTransactionSubmissionService extends Fake implements TransactionSubmissionService {
  /// Each transfer's recipient, amount and fee.
  final transfers = <(String, BigInt, BigInt)>[];

  /// Each multisig proposal's recipient, amount and expiry block.
  final proposals = <(String, BigInt, int)>[];

  /// The account that signed each multisig proposal, in [proposals]' order.
  final proposalSigners = <String>[];

  /// When set, a transfer waits for it before going out.
  Completer<void>? holdTransfer;

  @override
  Future<String> balanceTransfer(
    Account account, {
    required RuntimeCall call,
    required String targetAddress,
    required BigInt amount,
    required BigInt fee,
  }) async {
    await holdTransfer?.future;
    transfers.add((targetAddress, amount, fee));
    return '0xtxhash';
  }

  @override
  Future<String> submitExternallySignedTransfer({
    required Account account,
    required String targetAddress,
    required BigInt amount,
    required BigInt fee,
    required int blockHeight,
    required UnsignedTransactionData unsignedData,
    required Uint8List signatureWithPublicKey,
  }) async {
    await holdTransfer?.future;
    transfers.add((targetAddress, amount, fee));
    return '0xtxhash';
  }

  @override
  Future<String> proposeTransfer({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
    required ProposeFeeBreakdown feeBreakdown,
  }) async {
    await holdTransfer?.future;
    proposals.add((recipient, amount, expiryBlock));
    proposalSigners.add(signer.accountId);
    return '0xproposal';
  }

  @override
  Future<String> proposeTransferWithExternalSignature({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
    required ProposeFeeBreakdown feeBreakdown,
    required UnsignedTransactionData unsignedData,
    required Uint8List signatureWithPublicKey,
  }) async {
    await holdTransfer?.future;
    proposals.add((recipient, amount, expiryBlock));
    proposalSigners.add(signer.accountId);
    return '0xproposal';
  }
}
