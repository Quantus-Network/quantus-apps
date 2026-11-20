import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_desktop_wallet/providers/boot_intro_provider.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/one_click_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/history_polling_manager.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/remote_config_service.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';

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

  /// The text kept under plain keys.
  final Map<String, String> strings = {};

  /// Why the next [setString] fails, once.
  Object? failNextStringWrite;

  /// What is kept under plain keys that is not the text their readers
  /// expect: a number, say, in a preferences file that was damaged.
  final Map<String, Object> strays = {};

  @override
  Object? getValue(String key) => strays[key] ?? strings[key] ?? bools[key];

  @override
  String? getString(String key) => (strays[key] ?? strings[key]) as String?;

  @override
  Future<void> setString(String key, String value) async {
    if (failNextStringWrite case final error?) {
      failNextStringWrite = null;
      throw error;
    }
    strays.remove(key);
    strings[key] = value;
  }

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

/// Stored settings on a slow disk: each write of the active account waits
/// until the test lets it finish with [finishWrites].
class SlowSettingsService extends FakeSettingsService {
  SlowSettingsService({super.activeAccount, super.multisigs});

  final List<Completer<void>> _writes = [];

  /// How many writes of the active account are waiting.
  int get pendingWrites => _writes.length;

  @override
  Future<void> setActiveAccount(DisplayAccount account) async {
    final write = Completer<void>();
    _writes.add(write);
    await write.future;
    activeAccount = account;
  }

  /// Makes every waiting write fail with [error].
  Future<void> failWrites(WidgetTester tester, Object error) async {
    final writes = [..._writes];
    _writes.clear();
    for (final write in writes) {
      write.completeError(error);
    }
    await tester.pumpAndSettle();
  }

  /// Lets every waiting write finish, then the ones those started, until
  /// none is left.
  Future<void> finishWrites(WidgetTester tester) async {
    while (_writes.isNotEmpty) {
      final writes = [..._writes];
      _writes.clear();
      for (final write in writes) {
        write.complete();
      }
      await tester.pumpAndSettle();
    }
  }
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
  _FakeSubstrateService(this.chain, {this.device});

  final FakeSendChain chain;

  /// The device that generates recovery phrases, where a test has one.
  final FakeWalletDevice? device;

  @override
  Future<String> generateMnemonic() => device!.generateMnemonic();

  @override
  bool isValidSS58Address(String address) => chain.isValidAddress(address);

  @override
  Future<ExtrinsicFeeData> getFeeForCall(Account account, RuntimeCall call) async {
    chain.quotes.add(chain.describe(call));
    return ExtrinsicFeeData(fee: await chain.fee(), blockHash: '0x', blockNumber: 1);
  }
}

/// A transfer as Send builds it: who is paid and how much. An [amount] of
/// null is a transfer of everything the account has.
typedef SendCall = ({String recipient, BigInt? amount});

/// The chain as Send reaches it: which addresses are valid, what a transfer
/// costs, the transfers handed over, and the addresses paid before.
class FakeSendChain {
  /// The fee the mocks were drawn with: 0.0012 of a token.
  static final BigInt usualFee = oneToken * BigInt.from(12) ~/ BigInt.from(10000);

  /// Whether [address] is a valid address: here, one that starts with `qz`.
  bool Function(String address) isValidAddress = (address) => address.startsWith('qz') && !address.contains(' ');

  /// What a fee quote answers; it may throw.
  Future<BigInt> Function() fee = () async => usualFee;

  /// Every transfer a fee was asked for, in order.
  final quotes = <SendCall>[];

  /// What handing a transfer over answers, the transaction's hash; it may
  /// throw.
  Future<String> Function() submit = () async => '0xhash';

  /// Every transfer handed over: the account it left, the transfer, and the
  /// amount and fee it was recorded with.
  final transfers = <({String from, SendCall call, BigInt amount, BigInt fee})>[];

  /// What proposing a transfer costs the member who proposes, as the mocks
  /// drew it: the usual fee, half a token of deposit and a tenth for the
  /// proposal, expiring at block 1284220.
  static final usualProposalCost = ProposeFeeBreakdown(
    networkFee: usualFee,
    deposit: oneToken ~/ BigInt.two,
    creationFee: oneToken ~/ BigInt.from(10),
    expiryBlock: 1284220,
  );

  /// What asking for a proposal's cost answers; it may throw.
  Future<ProposeFeeBreakdown> Function() proposalCost = () async => usualProposalCost;

  /// Every recipient a proposal's cost was asked for, in order.
  final proposalQuotes = <String>[];

  /// Every proposal handed over: the multisig it is for, the member who
  /// signed it, and what it proposes.
  final proposals = <({String multisig, String signer, String recipient, BigInt amount, int expiryBlock})>[];

  /// When the chain is said to reach any block.
  DateTime blockTime = DateTime(2026, 11, 20, 22, 14);

  /// What reading the chain's latest block answers; it may throw.
  Future<int> Function() currentBlock = () async => 1250000;

  /// How many times the latest block was read.
  int currentBlockReads = 0;

  /// The addresses paid before, the latest first.
  List<String> recents = [];

  /// An account's history as the indexer gives it, a page at a time: the
  /// first page also holds [scheduledTransfers]. Every account reads the
  /// same history.
  List<List<TransactionEvent>> historyPages = const [];

  /// The reversible transfers waiting to run.
  List<ReversibleTransferEvent> scheduledTransfers = const [];

  /// When set, the reversible transfers waiting to run a page at a time, in
  /// place of [scheduledTransfers]; there is more while either list has a
  /// page after the one read.
  List<List<ReversibleTransferEvent>>? scheduledPages;

  /// The pages of history whose read fails, with [historyError] or a
  /// [StateError].
  Set<int> failingHistoryPages = const {};

  /// When set, every read of history waits for it.
  Completer<void>? holdHistory;

  /// When set, a read of history fails with this.
  Object? historyError;

  /// The pages of history read, by their number, in order.
  final historyReads = <int>[];

  /// A multisig's open proposals, and its past ones, as the indexer gives
  /// them.
  List<MultisigProposal> openProposals = const [];
  List<MultisigProposal> pastProposals = const [];

  /// When set, a read of past proposals waits for it; and fails with
  /// [pastProposalsError], when that is set.
  Completer<void>? holdPastProposals;
  Object? pastProposalsError;

  final _calls = Expando<SendCall>();

  SendCall describe(RuntimeCall call) => _calls[call] ?? (throw StateError('A call this chain did not build: $call'));

  /// With [substrate] left out by a test that overrides it itself.
  List<Override> overrides({bool substrate = true}) => [
    if (substrate) substrateServiceProvider.overrideWithValue(_FakeSubstrateService(this)),
    balancesServiceProvider.overrideWithValue(_FakeBalancesService(this)),
    transactionSubmissionServiceProvider.overrideWithValue(_FakeTransactionSubmissionService(this)),
    recentAddressesServiceProvider.overrideWithValue(_FakeRecentAddressesService(this)),
    multisigServiceProvider.overrideWithValue(_FakeMultisigService(this)),
    chainHistoryServiceProvider.overrideWithValue(_FakeChainHistoryService(this)),
  ];
}

/// Prices a multisig's proposals as the [chain] says, at the block it says
/// (1250000 unless told otherwise).
class _FakeMultisigService extends Fake implements MultisigService {
  _FakeMultisigService(this.chain);

  final FakeSendChain chain;

  @override
  Future<ProposeFeeBreakdown> estimateProposeFeeBreakdown({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
  }) {
    chain.proposalQuotes.add(recipient);
    return chain.proposalCost();
  }

  @override
  Future<int> currentBlockNumber() {
    chain.currentBlockReads++;
    return chain.currentBlock();
  }

  @override
  DateTime blockToTime(int targetBlock, int currentBlock) => chain.blockTime;

  @override
  Future<List<MultisigProposal>> getOpenProposals(MultisigAccount msig) async => chain.openProposals;

  @override
  Future<List<MultisigProposal>> getPastProposals(MultisigAccount msig) async {
    await chain.holdPastProposals?.future;
    if (chain.pastProposalsError case final error?) throw error;
    return chain.pastProposals;
  }
}

/// The indexer's history, as the [chain] holds it: each page's cursor is the
/// number of the page after it.
class _FakeChainHistoryService extends Fake implements ChainHistoryService {
  _FakeChainHistoryService(this.chain);

  final FakeSendChain chain;

  @override
  Future<SortedTransactionsList> fetchAllTransactionTypes({
    required List<String> accountIds,
    int limit = 20,
    AccountEventCursor? otherAfter,
    AccountEventCursor? scheduledAfter,
    required TransactionFilter filter,
  }) async {
    final page = otherAfter == null ? 0 : int.parse(otherAfter.id);
    chain.historyReads.add(page);
    await chain.holdHistory?.future;
    if (chain.historyError case final error?) throw error;
    if (chain.failingHistoryPages.contains(page)) throw StateError('page $page could not be read');
    final pages = chain.historyPages;
    final scheduledPages = chain.scheduledPages;
    final hasMore = page < pages.length - 1 || (scheduledPages != null && page < scheduledPages.length - 1);
    return SortedTransactionsList(
      scheduledReversibleTransfers: scheduledPages != null
          ? (page < scheduledPages.length ? scheduledPages[page] : const [])
          : (page == 0 ? chain.scheduledTransfers : const []),
      otherTransfers: page < pages.length ? pages[page] : const [],
      nextOtherCursor: hasMore ? AccountEventCursor(timestamp: '', id: '${page + 1}') : null,
      hasMore: hasMore,
    );
  }
}

/// Builds the transfer calls without the chain's address decoding, and tells
/// the [chain] what each one is.
class _FakeBalancesService extends Fake implements BalancesService {
  _FakeBalancesService(this.chain);

  final FakeSendChain chain;

  static final _anyDest = const multi_address.$MultiAddress().id(List<int>.filled(32, 0));

  @override
  Balances getBalanceTransferCall(String targetAddress, BigInt amount) {
    if (!chain.isValidAddress(targetAddress)) throw ArgumentError.value(targetAddress, 'targetAddress');
    final call = const balances_pallet.Txs().transferAllowDeath(dest: _anyDest, value: amount);
    chain._calls[call] = (recipient: targetAddress, amount: amount);
    return call;
  }

  @override
  Balances getTransferAllCall(String targetAddress) {
    if (!chain.isValidAddress(targetAddress)) throw ArgumentError.value(targetAddress, 'targetAddress');
    final call = const balances_pallet.Txs().transferAll(dest: _anyDest, keepAlive: false);
    chain._calls[call] = (recipient: targetAddress, amount: null);
    return call;
  }
}

class _FakeTransactionSubmissionService extends Fake implements TransactionSubmissionService {
  _FakeTransactionSubmissionService(this.chain);

  final FakeSendChain chain;

  @override
  Future<String> balanceTransfer(
    Account account, {
    required RuntimeCall call,
    required String targetAddress,
    required BigInt amount,
    required BigInt fee,
  }) async {
    final hash = await chain.submit();
    chain.transfers.add((from: account.accountId, call: chain.describe(call), amount: amount, fee: fee));
    return hash;
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
    final hash = await chain.submit();
    chain.proposals.add((
      multisig: msig.accountId,
      signer: signer.accountId,
      recipient: recipient,
      amount: amount,
      expiryBlock: expiryBlock,
    ));
    return hash;
  }
}

class _FakeRecentAddressesService extends Fake implements RecentAddressesService {
  _FakeRecentAddressesService(this.chain);

  final FakeSendChain chain;

  @override
  Future<List<String>> getAddresses() async => List.of(chain.recents);

  @override
  Future<void> addAddress(String address) async =>
      chain.recents = [address, ...chain.recents.where((a) => a != address)];
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
      ..strings.clear()
      ..activeAccount = null;
  }
}

/// A device and a chain for the flows that create, import or wipe a wallet.
/// It starts with no wallet. Every balance is [balance].
class FakeWalletDevice {
  final storage = FakeWalletStorage();

  /// The chain as Send reaches it.
  final chain = FakeSendChain();

  /// What every transparent account holds.
  BigInt balance = oneToken;

  /// The deposits, in tokens, an Encrypted account can spend, and the tokens
  /// of change still on their way back to it. With no deposits it holds one
  /// token and nothing to spend.
  List<int> encryptedDeposits = const [];
  int encryptedPending = 0;

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
    substrateServiceProvider.overrideWithValue(_FakeSubstrateService(chain, device: this)),
    ...chain.overrides(substrate: false),
    accountDiscoveryServiceProvider.overrideWithValue(_FakeAccountDiscoveryService(this)),
    logoutServiceProvider.overrideWithValue(_WipingLogoutService(this)),
    remoteConfigProvider.overrideWith(
      (ref) => RemoteConfigNotifier(FakeRemoteConfigService(RemoteConfigModel.defaults)),
    ),
    balanceProviderFamily.overrideWith((ref, accountId) => balance),
    encryptedBalanceProvider.overrideWith(
      (ref, walletIndex) =>
          AsyncValue.data(encryptedDeposits.isEmpty ? oneToken : _encryptedState(walletIndex).balance),
    ),
    encryptedStateProvider.overrideWith((ref, walletIndex) => _encryptedState(walletIndex)),
  ];

  EncryptedAccountState _encryptedState(int walletIndex) => EncryptedAccountState(
    accountId: 'qzEncrypted$walletIndex',
    ownAddresses: const {},
    received: const [],
    spends: const {},
    utxos: [for (final tokens in encryptedDeposits) encryptedUtxo(tokens)],
    pendingChangeToken: oneToken * BigInt.from(encryptedPending),
    nextIndex: 0,
    nextChangeIndex: 0,
  );
}

/// The polling that keeps an open wallet current, which only notes what the
/// app asks of it.
class FakeHistoryPollingManager extends Fake implements HistoryPollingManager {
  /// How many times the app set it going.
  int starts = 0;

  /// What the app asked of it since, in order: `pause`, `resume`,
  /// `silentRefresh` or `manualRefresh`.
  final calls = <String>[];

  /// When set, a refresh fails with this.
  Object? refreshError;

  /// When set, a refresh waits for it.
  Completer<void>? holdRefresh;

  @override
  void pausePolling() => calls.add('pause');

  @override
  void resumePolling() => calls.add('resume');

  @override
  Future<void> triggerSilentRefresh() => _refresh('silentRefresh');

  @override
  Future<void> triggerManualRefresh() => _refresh('manualRefresh');

  Future<void> _refresh(String call) async {
    calls.add(call);
    await holdRefresh?.future;
    if (refreshError case final error?) throw error;
  }
}

/// Whether the computer has a network, as a test says. It has one unless
/// told otherwise.
class FakeNetwork {
  final _changes = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status = NetworkStatus.online;

  /// The status now, then each change.
  Stream<NetworkStatus> get statusStream async* {
    yield _status;
    yield* _changes.stream;
  }

  void goOffline() => _set(NetworkStatus.offline);

  void goOnline() => _set(NetworkStatus.online);

  void _set(NetworkStatus status) {
    _status = status;
    _changes.add(status);
  }
}

/// Stands in for what keeps an open wallet current, so no test polls the
/// chain or asks the computer about its network. With [realPolling] the
/// app's own polling runs instead, reading whatever else the test fakes.
List<Override> liveDataOverrides({FakeHistoryPollingManager? polling, FakeNetwork? network, bool realPolling = false}) {
  assert(!realPolling || polling == null, 'real polling cannot be a fake one as well');
  final manager = polling ?? FakeHistoryPollingManager();
  return [
    if (!realPolling)
      historyPollingManagerProvider.overrideWith((ref) {
        manager.starts++;
        return manager;
      }),
    networkStatusProvider.overrideWith((ref) => (network ?? FakeNetwork()).statusStream),
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

/// The system's check of the login password, answering as a test says.
class FakeLoginPassword implements LoginPassword {
  bool isSetUpAnswer = true;

  /// When set, asking whether the check is set up fails with this.
  Object? isSetUpError;

  /// The login password.
  String password = 'correct horse';

  /// Every password that was checked.
  final checked = <String>[];

  /// What the system says during a check.
  List<String> messages = [];

  /// When set, a check fails with this.
  Object? error;

  /// When set, a check answers (or fails) only once this completes.
  Completer<void>? held;

  @override
  Future<bool> isSetUp() async {
    if (isSetUpError case final error?) throw error;
    return isSetUpAnswer;
  }

  @override
  Future<LoginPasswordResult> check(String password, {required void Function(String message) onMessage}) async {
    checked.add(password);
    messages.forEach(onMessage);
    if (held case final held?) await held.future;
    if (error case final error?) throw error;
    return password == this.password ? LoginPasswordResult.accepted : LoginPasswordResult.refused;
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
/// a load to hang or fail. The system's approval is [approval], or one that
/// approves; Send reaches the chain through [chain].
List<Override> shellOverrides({
  List<Account> accounts = const [],
  Future<List<Account>> Function()? loadAccounts,
  FakeSettingsService? settings,
  Map<String, BigInt> balances = const {},
  Future<BigInt> Function(String accountId)? balanceOf,
  Map<int, BigInt> encryptedBalances = const {},
  bool swapAvailable = true,
  Future<String> Function(int walletIndex)? depositAddress,
  FakeUserApproval? approval,
  FakeSendChain? chain,
  Map<int, EncryptedAccountState> encryptedStates = const {},
  Set<String> ownEncryptedAddresses = const {},
  FakeOneClickService? oneClick,
  FakeEncryptedSendController? proving,
}) {
  return [
    systemApprovalProvider.overrideWithValue(approval ?? FakeUserApproval()),
    ...(chain ?? FakeSendChain()).overrides(),
    if (depositAddress != null || encryptedStates.isNotEmpty)
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) => FakeEncryptedAccountService(
          depositAddress == null
              ? () async => throw StateError('no deposit address set for wallet $walletIndex')
              : () => depositAddress(walletIndex),
          ownAddresses: ownEncryptedAddresses,
        ),
      ),
    oneClickServiceProvider.overrideWithValue(oneClick ?? FakeOneClickService()),
    if (proving != null) encryptedSendControllerProvider.overrideWith(() => proving),
    if (encryptedStates.isNotEmpty)
      encryptedStateProvider.overrideWith((ref, walletIndex) {
        final state = encryptedStates[walletIndex];
        if (state == null) throw StateError('no encrypted state set for wallet $walletIndex');
        return state;
      })
    else
      // Read for the Encrypted account's activity: it has none.
      encryptedStateProvider.overrideWith((ref, walletIndex) => emptyEncryptedState(walletIndex)),
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
      final balance = encryptedBalances[walletIndex] ?? encryptedStates[walletIndex]?.balance;
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
/// [nextAddress], and whose own addresses are [ownAddresses].
class FakeEncryptedAccountService extends Fake implements EncryptedAccountService {
  FakeEncryptedAccountService(this.nextAddress, {this.ownAddresses = const {}});

  final Future<String> Function() nextAddress;
  final Set<String> ownAddresses;

  @override
  Future<bool> ownsAddress(String address) async => ownAddresses.contains(address);

  @override
  Future<WormholeKeyPair> receiveKeyPair() async =>
      WormholeKeyPair(address: await nextAddress(), addressHex: '', rewardsPreimageHex: '', secretHex: '');
}

/// 1Click's word on which addresses are its single-use deposit addresses:
/// those in [deposits]. An answer may be held back with [gate].
class FakeOneClickService extends Fake implements OneClickService {
  FakeOneClickService({this.deposits = const {}});

  final Set<String> deposits;

  /// When set, every lookup waits for this first.
  Future<void>? gate;
  final _answered = <String>{};

  @override
  Future<bool> isDepositAddress(String address) async {
    await gate;
    _answered.add(address);
    return deposits.contains(address);
  }

  @override
  bool isKnownDepositAddress(String address) => _answered.contains(address) && deposits.contains(address);
}

/// A deposit of [tokens] that an Encrypted account can spend.
WormholeUtxo encryptedUtxo(int tokens) {
  final scaled = wormholeScaledFromToken(oneToken * BigInt.from(tokens));
  return WormholeUtxo(
    transfer: WormholeTransfer(
      id: 't$tokens',
      blockHeight: 1,
      timestamp: DateTime(2026),
      fromId: 'from',
      toId: 'to',
      amount: wormholeTokenFromScaled(scaled),
      toHash: '0x00',
      leafIndex: BigInt.from(tokens),
      transferCount: BigInt.one,
      extrinsicId: '',
      viaWormhole: false,
    ),
    owner: const WormholeAddressInfo(index: 0, address: 'addr', secretHex: '0x00'),
    nullifierHex: '0xn$tokens',
  );
}

/// What an Encrypted account holds: a deposit of each of [deposits] tokens
/// to spend, and [pending] tokens of change still on their way back.
EncryptedAccountState encryptedHolding(List<int> deposits, {int pending = 0}) => EncryptedAccountState(
  accountId: encryptedAccount.accountId,
  ownAddresses: const {},
  received: const [],
  spends: const {},
  utxos: [for (final tokens in deposits) encryptedUtxo(tokens)],
  pendingChangeToken: oneToken * BigInt.from(pending),
  nextIndex: 0,
  nextChangeIndex: 0,
);

/// The proving of a private send, driven by the test: it records what it was
/// started with and how often it was asked to stop, and is in whatever state
/// [report] last gave it.
class FakeEncryptedSendController extends EncryptedSendController {
  final starts = <({Account account, WormholeSpendPlan plan, BigInt amount, String recipient})>[];
  int cancels = 0;

  /// Nothing listened to the proving any more, which stops it.
  bool wasDisposed = false;

  @override
  EncryptedSendState build() {
    ref.onDispose(() => wasDisposed = true);
    return EncryptedSendState(phase: EncryptedSendPhase.idle);
  }

  @override
  Future<void> start({
    required Account account,
    required WormholeSpendPlan plan,
    required BigInt amount,
    required String recipientAddress,
  }) async {
    starts.add((account: account, plan: plan, amount: amount, recipient: recipientAddress));
    state = state.copyWith(phase: EncryptedSendPhase.running);
  }

  @override
  Future<void> cancel() async {
    cancels++;
    state = state.copyWith(phase: EncryptedSendPhase.canceling);
  }

  void report(EncryptedSendState next) => state = next;
}

/// Pumps the whole app in a window of the size the runners open, and waits for
/// it to settle unless [settle] is false (a loader never settles).
///
/// The system asks for reduced motion unless [reduceMotion] is false: the
/// Welcome page's moving background never settles either, so only the tests
/// about that motion turn it on.
///
/// The open wallet's polling is a fake one ([polling]) unless [realPolling]
/// asks for the app's own.
Future<void> pumpShell(
  WidgetTester tester, {
  required List<Override> overrides,
  FakeLoginPassword? loginPassword,
  FakeHistoryPollingManager? polling,
  bool realPolling = false,
  FakeNetwork? network,
  bool settle = true,
  bool reduceMotion = true,
}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  useFakeCheckphrases(fakeCheckphrase);

  await tester.pumpWidget(
    buildApp(
      overrides: [
        ...overrides,
        // Never the computer's own PAM, which a test run as Linux would
        // otherwise reach.
        loginPasswordProvider.overrideWithValue(loginPassword ?? FakeLoginPassword()),
        ...liveDataOverrides(polling: polling, network: network, realPolling: realPolling),
      ],
    ),
  );
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

/// An Encrypted account of wallet [walletIndex] that has received nothing.
EncryptedAccountState emptyEncryptedState(int walletIndex) => EncryptedAccountState(
  accountId: 'qzEncrypted$walletIndex',
  ownAddresses: const {},
  received: const [],
  spends: const {},
  utxos: const [],
  pendingChangeToken: BigInt.zero,
  nextIndex: 0,
  nextChangeIndex: 0,
);
