import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_desktop_wallet/providers/boot_intro_provider.dart';
import 'package:quantus_desktop_wallet/providers/keystone_signing_providers.dart';
import 'package:quantus_desktop_wallet/services/background_window.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';
import 'package:quantus_desktop_wallet/services/mac_push.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/testing/call_corpus.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/providers/one_click_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/history_polling_manager.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/remote_config_service.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';

import 'services/fake_background_window.dart';
import 'services/fake_mac_push.dart';
import 'services/fake_notification_plugin.dart';

/// The stored settings the shell reads, without the device's storage. A
/// wallet with its recovery phrase is there unless a test says otherwise.
class FakeSettingsService extends Fake implements SettingsService {
  FakeSettingsService({
    this.activeAccount,
    this.multisigs = const [],
    this.walletNames = const {},
    Map<int, String>? mnemonics,
    Set<int> openWallets = const {},
  }) : mnemonics = mnemonics ?? {0: 'a stored recovery phrase'} {
    if (openWallets.isNotEmpty) strings[KeptOpenWalletsNotifier.settingsKey] = openWallets.join(',');
  }

  DisplayAccount? activeAccount;
  final List<MultisigAccount> multisigs;
  final Map<int, String> walletNames;
  final Map<int, String> mnemonics;

  /// The swaps being followed, as the device keeps them.
  List<ActiveSwap> activeSwaps = [];

  /// The one swap the desktop follows at a time, as the device keeps it.
  ActiveSwap? get activeSwap => activeSwaps.singleOrNull;
  set activeSwap(ActiveSwap? swap) => activeSwaps = [?swap];

  /// The flags kept under plain keys. The boot intro counts as seen already,
  /// so it plays only in the tests that are about it.
  final Map<String, bool> bools = {BootIntroSeenNotifier.settingsKey: true};

  @override
  bool? getBool(String key) => bools[key];

  /// Why the next [setBool] fails, once.
  Object? failNextBoolWrite;

  @override
  Future<void> setBool(String key, bool value) async {
    if (failNextBoolWrite case final error?) {
      failNextBoolWrite = null;
      throw error;
    }
    bools[key] = value;
  }

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
  Future<void> clearSelectedAppLocale() async => locale = null;

  @override
  String? getSelectedFiatCurrency() => null;

  @override
  Future<void> clearSelectedFiatCurrency() async {}
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
  SlowSettingsService({super.activeAccount, super.multisigs, super.openWallets});

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

  /// When set, reading a recovery phrase waits for this first.
  Future<void>? mnemonicGate;

  /// How many times a recovery phrase was read.
  int mnemonicReads = 0;

  @override
  Future<String?> getMnemonic(int walletIndex) async {
    mnemonicReads++;
    if (mnemonicGate case final gate?) await gate;
    return super.getMnemonic(walletIndex);
  }

  /// How many times the device was asked whether it has a wallet.
  int hasWalletChecks = 0;

  /// When set, saving a recovery phrase fails with this.
  Object? mnemonicWriteError;

  /// When set, deriving a wallet's encrypted account waits for this first.
  Future<void>? encryptedAccountsGate;

  /// When set, adding an account waits for this first.
  Future<void>? addAccountGate;

  @override
  Future<List<Account>> getAccounts() async => List.of(accounts);

  @override
  Future<int> getNextFreeAccountIndex(int walletIndex, {DilithiumScheme? scheme}) async {
    final used = {
      for (final account in accounts)
        if (account.walletIndex == walletIndex) account.index,
    };
    var index = 0;
    while (used.contains(index)) {
      index++;
    }
    return index;
  }

  @override
  Future<bool> getHasWallet() async {
    hasWalletChecks++;
    await hasWalletGate;
    if (hasWalletError case final error?) throw error;
    return accounts.isNotEmpty;
  }

  /// When set, adding an account fails with this, and nothing is added.
  Object? addAccountError;

  /// When set, storing the active account fails with this.
  Object? activeWriteError;

  @override
  Future<void> setActiveAccount(DisplayAccount account) async {
    if (activeWriteError case final error?) throw error;
    activeAccount = account;
  }

  @override
  Future<void> addAccount(Account account) async {
    await addAccountGate;
    if (addAccountError case final error?) throw error;
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

  /// When set, removing or renaming an account, a wallet or a multisig fails
  /// with this, and nothing is changed.
  Object? writeError;

  void _checkWrite() {
    if (writeError case final error?) throw error;
  }

  /// Makes a non-encrypted account of [remaining] active when the active one
  /// is not among them, as the device's storage does.
  void _keepActiveIn(List<Account> remaining) {
    final activeId = activeAccount?.account.accountId;
    if (activeId == null || remaining.any((a) => a.accountId == activeId)) return;
    if (multisigStore.any((m) => m.accountId == activeId)) return;
    final replacement = remaining.firstWhere(
      (a) => a.accountType != AccountType.encrypted,
      orElse: () => remaining.first,
    );
    activeAccount = RegularAccount(replacement);
  }

  @override
  Future<void> removeAccount(Account account) async {
    _checkWrite();
    final remaining = accounts.where((a) => a.accountId != account.accountId).toList();
    _keepActiveIn(remaining);
    accounts
      ..clear()
      ..addAll(remaining);
    // A wallet goes with its last account, as a hardware wallet's can.
    if (!remaining.any((a) => a.walletIndex == account.walletIndex)) names.remove(account.walletIndex);
  }

  @override
  Future<void> removeWallet(int walletIndex) async {
    _checkWrite();
    final remaining = accounts.where((a) => a.walletIndex != walletIndex).toList();
    _keepActiveIn(remaining);
    accounts
      ..clear()
      ..addAll(remaining);
    mnemonics.remove(walletIndex);
    names.remove(walletIndex);
  }

  @override
  Future<void> updateAccount(Account account) async {
    _checkWrite();
    final index = accounts.indexWhere((a) => a.accountId == account.accountId);
    if (index < 0) throw StateError('${account.accountId} is not stored');
    accounts[index] = account;
    if (activeAccount?.account.accountId == account.accountId) activeAccount = RegularAccount(account);
  }

  /// The wallets' names, by wallet index.
  final Map<int, String> names = {};

  @override
  String? getWalletName(int walletIndex) => names[walletIndex];

  @override
  Future<void> setWalletName(int walletIndex, String? name) async {
    _checkWrite();
    if (name == null || name.isEmpty) {
      names.remove(walletIndex);
    } else {
      names[walletIndex] = name;
    }
  }

  /// The multisigs on the device.
  final List<MultisigAccount> multisigStore = [];

  @override
  Future<List<MultisigAccount>> getMultisigAccounts() async => List.of(multisigStore);

  /// When set, adding or removing a multisig waits for this first.
  Completer<void>? multisigWriteGate;

  @override
  Future<void> addMultisigAccount(MultisigAccount account) async {
    await multisigWriteGate?.future;
    _checkWrite();
    if (multisigStore.any((m) => m.accountId == account.accountId)) throw Exception('Multisig already added');
    multisigStore.add(account);
  }

  @override
  Future<void> updateMultisigAccount(MultisigAccount account) async {
    _checkWrite();
    final index = multisigStore.indexWhere((m) => m.accountId == account.accountId);
    if (index < 0) throw StateError('${account.accountId} is not stored');
    multisigStore[index] = account;
  }

  @override
  Future<void> removeMultisigAccount(String accountId) async {
    await multisigWriteGate?.future;
    _checkWrite();
    multisigStore.removeWhere((m) => m.accountId == accountId);
    if (activeAccount?.account.accountId == accountId) activeAccount = RegularAccount(accounts.first);
  }

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

  /// The wallet's next free account, as the real service derives it from the
  /// wallet's phrase.
  @override
  Future<Account> createNewAccount({required int walletIndex}) async {
    if (await storage.getMnemonic(walletIndex) == null) {
      throw Exception('Mnemonic not found. Cannot create new account.');
    }
    final used = {
      for (final account in storage.accounts)
        if (account.walletIndex == walletIndex && account.accountType != AccountType.encrypted) account.index,
    };
    var index = 0;
    while (used.contains(index)) {
      index++;
    }
    return Account(
      walletIndex: walletIndex,
      index: index,
      name: 'Account ${storage.accounts.length + 1}',
      accountId: 'qzNew$walletIndex-$index',
    );
  }

  @override
  Future<void> removeAccount(Account account) => storage.removeAccount(account);

  @override
  Future<void> removeWallet(int walletIndex) => storage.removeWallet(walletIndex);

  @override
  Future<void> updateAccountName(Account account, String name) => storage.updateAccount(account.copyWith(name: name));

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
  Future<void> logout() async {
    device!.logouts++;
    device!._wipeStorage();
  }

  @override
  bool isValidSS58Address(String address) => chain.isValidAddress(address);

  @override
  Future<ExtrinsicFeeData> getFeeForCall(Account account, RuntimeCall call) async {
    chain.quotes.add(chain.describe(call));
    return ExtrinsicFeeData(fee: await chain.fee(), blockHash: '0x', blockNumber: 1);
  }

  @override
  Future<BigInt> queryBalance(String address) async => device!.balance;

  @override
  Future<UnsignedTransactionData> getUnsignedTransactionPayload(Account account, RuntimeCall call) {
    final transfer = chain.describe(call);
    chain.signRequests.add(transfer);
    return chain.unsigned(transfer);
  }

  @override
  Future<int> getCurrentBlockNumber() => chain.currentBlock();
}

/// A transaction as a cold wallet is handed it, built at [blockNumber] and
/// alive for [eraPeriod] blocks: by default ten blocks before the chain's
/// usual latest, 1250000, so it ends at 1250054.
UnsignedTransactionData fakeUnsignedTransaction({int blockNumber = 1249990, int eraPeriod = 64}) =>
    UnsignedTransactionData(
      payloadToSign: QuantusSigningPayload(
        method: Uint8List(0),
        specVersion: 1,
        transactionVersion: 1,
        genesisHash: '0x00',
        blockHash: '0x00',
        blockNumber: blockNumber,
        eraPeriod: eraPeriod,
        nonce: 0,
        tip: 0,
      ),
      signer: Uint8List(32),
      registry: Object(),
    );

/// The frames of a cold wallet's signature, [total] of them, as the fake
/// collector reads them: `ur:quantus-signature/<index>-<total>/`.
List<String> fakeSignatureFrames(int total) => [
  for (var index = 1; index <= total; index++) 'ur:quantus-signature/$index-$total/part$index',
];

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

  /// What building the request a cold wallet signs answers, by the transfer;
  /// it may throw.
  Future<UnsignedTransactionData> Function(SendCall transfer) unsigned = (_) async => fakeUnsignedTransaction();

  /// Every transfer a request for a cold wallet was built for, in order.
  final signRequests = <SendCall>[];

  /// The frames of the request a cold wallet scans: here one, naming the
  /// account and the block the transaction was built at.
  static List<String> requestFrames(Account account, UnsignedTransactionData unsigned) => [
    'UR:QUANTUS-SIGN-REQUEST/${account.accountId}/${unsigned.payloadToSign.blockNumber}',
  ];

  /// What a cold wallet's signature frames decode to: by default a
  /// signature with its public key of ML-DSA-87's length.
  Uint8List signature = Uint8List(DilithiumScheme.mlDsa87.signatureWithPublicKeyBytes);

  /// When set, decoding a signature's frames fails with it.
  Object? signatureDecodeError;

  /// Every transfer a cold wallet signed that was handed over: the account
  /// it left, who is paid, how much, its fee, the transaction signed and the
  /// signature.
  final signedTransfers =
      <
        ({
          String from,
          String recipient,
          BigInt amount,
          BigInt fee,
          UnsignedTransactionData unsigned,
          Uint8List signature,
        })
      >[];

  /// When set, handing a signed transfer over waits for it.
  Completer<void>? holdSignedSubmit;

  /// Collects the frames of [fakeSignatureFrames] without Rust.
  UrScanAccumulator signatureCollector() => UrScanAccumulator(
    isAcceptable: (part) => part.startsWith('ur:quantus-signature/'),
    isComplete: (parts) {
      final total = urSequenceFor(parts.first)!.total;
      return {for (final part in parts) urSequenceFor(part)!.index}.length == total;
    },
    decode: (_) => signatureDecodeError == null ? signature : throw signatureDecodeError!,
    maxParts: 256,
  );

  /// The transfers the indexer holds, by the hash of the transaction each was
  /// sent in.
  final indexedTransfers = <String, TransactionEvent>{};

  /// When set, reading a transfer by its hash fails with this.
  Object? transferLookupError;

  /// The hashes of the transfers read, in order.
  final transferLookups = <String>[];

  /// The proposals the indexer holds as created, by the hash of the
  /// transaction each was created in.
  final indexedProposals = <String, MultisigProposalCreatedEvent>{};

  /// When set, looking a proposal up by its hash fails with this.
  Object? proposalLookupError;

  /// When set, looking a proposal up by its hash waits for it.
  Completer<void>? holdProposalLookup;

  /// When set, a search of the indexer by transaction hash waits for it.
  Completer<void>? holdHashSearch;

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

  /// The call a proposal stores on chain, as reading it answers; it may
  /// throw. A sample transfer unless told otherwise.
  Future<List<int>> Function(int proposalId) proposalCall = (_) async => corpusCall('Balances.transfer_allow_death');

  /// What pricing an approval, execution or cancellation answers; it may
  /// throw.
  Future<BigInt> Function() actionFee = () async => usualFee;

  /// Every approval, execution or cancellation priced, in order: the action,
  /// the account that signs it, and the call it was priced with.
  final actionQuotes = <(String action, String signer, List<int>? callBytes)>[];

  /// What handing an approval, execution or cancellation over answers, the
  /// transaction's hash; it may throw.
  Future<String> Function() submitAction = () async => '0xaction';

  /// Every approval, execution or cancellation handed over: the action, the
  /// account that signed it, its fee and the call it carried.
  final actions = <(String action, String signer, BigInt? fee, List<int>? callBytes)>[];

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

  /// The pages of history whose reads wait for their completer.
  final holdHistoryPages = <int, Completer<void>>{};

  /// When set, a read of history fails with this.
  Object? historyError;

  /// The pages of history read, by their number, in order.
  final historyReads = <int>[];

  /// What the indexer answers when asked for the multisigs an account signs
  /// for, and how many times it was asked.
  Future<List<MultisigAccount>> Function() discoverMultisigs = () async => const [];
  int discoverReads = 0;

  /// The address a new multisig of [signerCount] signers needing [threshold]
  /// approvals gets at [nonce].
  static String newMultisigAddress(int signerCount, int threshold, BigInt nonce) =>
      'qzNew${signerCount}of$threshold#$nonce';

  /// What working out a new multisig's address answers; it may throw.
  Future<MultisigCreationParams> Function(List<String> signers, int threshold) resolveMultisig =
      (signers, threshold) async => MultisigCreationParams(
        nonce: BigInt.zero,
        address: newMultisigAddress(signers.length, threshold, BigInt.zero),
      );

  /// The addresses set aside each time a new multisig's address was worked
  /// out.
  final reservedMultisigReads = <Set<String>>[];

  /// The multisigs the indexer holds.
  final indexedMultisigs = <String>{};

  /// What handing a new multisig over answers; it may throw.
  Future<Uint8List> Function() submitMultisig = () async => Uint8List.fromList(const [1, 2, 3]);

  /// Every new multisig handed over.
  final createdMultisigs = <({String creator, List<String> signers, int threshold, BigInt? nonce})>[];

  /// A multisig's open proposals, and its past ones, as the indexer gives
  /// them.
  List<MultisigProposal> openProposals = const [];
  List<MultisigProposal> pastProposals = const [];

  /// When set, a read of open proposals waits for it.
  Completer<void>? holdOpenProposals;

  /// The multisigs whose open proposals were read, in order.
  final openProposalReads = <String>[];

  /// What is still scheduled to or from the accounts asked about, as the
  /// indexer gives it, and the accounts asked about each time.
  List<ReversibleTransferEvent> stillScheduled = const [];
  final stillScheduledReads = <List<String>>[];

  /// What each account received, oldest first, as the indexer holds it.
  final received = <String, List<TransactionEvent>>{};

  /// The indexer now holds [event] as received by the account [accountId].
  void receive(String accountId, TransactionEvent event) => received.putIfAbsent(accountId, () => []).add(event);

  /// The accounts asked what they received, each time, in order.
  final receivedReads = <List<String>>[];

  /// When set, a read of what accounts received fails with this; and waits
  /// for [holdReceived], when that is set.
  Object? receivedError;
  Completer<void>? holdReceived;

  /// What happened to each multisig's proposals, oldest first, as the indexer
  /// holds it.
  final proposalActivity = <String, List<MultisigProposalActivity>>{};

  /// The multisigs asked what happened to their proposals, each time, in
  /// order.
  final proposalActivityReads = <List<String>>[];

  /// When set, a read of what happened to proposals fails with this; and
  /// waits for [holdProposalActivity], when that is set.
  Object? proposalActivityError;
  Completer<void>? holdProposalActivity;

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
    keystoneSignRequestFramesProvider.overrideWithValue(requestFrames),
    signatureCollectorFactoryProvider.overrideWithValue(signatureCollector),
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

  /// A cursor counts, under every kind, how many of the multisig's records
  /// were read.
  @override
  Future<Map<String, MultisigProposalActivitySince>> fetchProposalActivitySince(
    List<MultisigAccount> multisigs,
    Map<String, MultisigProposalActivityCursor> cursors,
  ) async {
    chain.proposalActivityReads.add([for (final msig in multisigs) msig.accountId]);
    await chain.holdProposalActivity?.future;
    if (chain.proposalActivityError case final error?) throw error;
    return {
      for (final msig in multisigs)
        msig.accountId: MultisigProposalActivitySince(
          activity: switch (cursors[msig.accountId]) {
            null => const [],
            final cursor => [...?chain.proposalActivity[msig.accountId]?.skip(int.parse(cursor.values.first.id))],
          },
          cursor: {
            for (final kind in MultisigProposalActivityKind.values)
              kind: AccountEventCursor(timestamp: '', id: '${chain.proposalActivity[msig.accountId]?.length ?? 0}'),
          },
        ),
    };
  }

  @override
  Future<List<MultisigAccount>> discoverForUser(List<String> myAccountIds) {
    chain.discoverReads++;
    return chain.discoverMultisigs();
  }

  @override
  Future<MultisigCreationParams> resolveMultisigCreationParams({
    required List<String> signers,
    required int threshold,
    Set<String> reservedAddresses = const {},
    BigInt? startNonce,
    Future<bool> Function(String address)? isAddressTaken,
    Future<String> Function({required List<String> signers, required int threshold, required BigInt nonce})?
    predictAddress,
    int maxAttempts = 64,
  }) {
    chain.reservedMultisigReads.add(reservedAddresses);
    return chain.resolveMultisig(signers, threshold);
  }

  @override
  Future<String> predictMultisigAddress({required List<String> signers, required int threshold, BigInt? nonce}) async =>
      FakeSendChain.newMultisigAddress(signers.length, threshold, nonce ?? BigInt.zero);

  @override
  Future<bool> isMultisigIndexed(String address) async => chain.indexedMultisigs.contains(address);

  @override
  Multisig buildCreateMultisigCall({required List<String> signers, required int threshold, required BigInt nonce}) {
    final call = const multisig_pallet.Txs().createMultisig(signers: const [], threshold: threshold, nonce: nonce);
    chain._calls[call] = (recipient: 'a new multisig', amount: null);
    return call;
  }

  @override
  Future<Uint8List> submitCreateMultisigExtrinsic({
    required Account creator,
    required List<String> signers,
    required int threshold,
    BigInt? nonce,
  }) async {
    final hash = await chain.submitMultisig();
    chain.createdMultisigs.add((creator: creator.accountId, signers: signers, threshold: threshold, nonce: nonce));
    return hash;
  }

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
  Future<List<int>> fetchProposalCallBytes({required MultisigAccount msig, required int proposalId}) =>
      chain.proposalCall(proposalId);

  Future<BigInt> _actionFee(String action, Account signer, List<int>? callBytes) {
    chain.actionQuotes.add((action, signer.accountId, callBytes));
    return chain.actionFee();
  }

  @override
  Future<BigInt> estimateApproveFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) => _actionFee('approve', signer, callBytes);

  @override
  Future<BigInt> estimateExecuteFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) => _actionFee('execute', signer, callBytes);

  @override
  Future<BigInt> estimateCancelFee({required MultisigAccount msig, required Account signer, required int proposalId}) =>
      _actionFee('cancel', signer, null);

  @override
  DateTime blockToTime(int targetBlock, int currentBlock) => chain.blockTime;

  @override
  Future<List<MultisigProposal>> getOpenProposals(MultisigAccount msig) async {
    chain.openProposalReads.add(msig.accountId);
    await chain.holdOpenProposals?.future;
    return chain.openProposals;
  }

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
  Future<TransactionEvent?> searchByExtrinsicHash({required String extrinsicHash, required bool isReversible}) async {
    await chain.holdHashSearch?.future;
    chain.transferLookups.add(extrinsicHash);
    if (chain.transferLookupError case final error?) throw error;
    return chain.indexedTransfers[extrinsicHash];
  }

  @override
  Future<MultisigProposalCreatedEvent?> searchProposalCreatedByExtrinsicHash({required String extrinsicHash}) async {
    await chain.holdProposalLookup?.future;
    if (chain.proposalLookupError case final error?) throw error;
    return chain.indexedProposals[extrinsicHash];
  }

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
    await chain.holdHistoryPages[page]?.future;
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

  @override
  Future<List<ReversibleTransferEvent>> fetchStillScheduledTransfers({required List<String> accountIds}) async {
    chain.stillScheduledReads.add(accountIds);
    return chain.stillScheduled;
  }

  /// A cursor counts how many of the account's rows were read.
  @override
  Future<Map<String, IncomingSince>> fetchIncomingSince(Map<String, AccountEventCursor?> after) async {
    chain.receivedReads.add(after.keys.toList());
    await chain.holdReceived?.future;
    if (chain.receivedError case final error?) throw error;
    return {
      for (final MapEntry(key: account, value: cursor) in after.entries)
        account: IncomingSince(
          received: cursor == null ? const [] : [...?chain.received[account]?.skip(int.parse(cursor.id))],
          cursor: AccountEventCursor(timestamp: '', id: '${chain.received[account]?.length ?? 0}'),
        ),
    };
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
  Future<String> submitExternallySignedTransfer({
    required Account account,
    required String targetAddress,
    required BigInt amount,
    required BigInt fee,
    required int blockHeight,
    required UnsignedTransactionData unsignedData,
    required Uint8List signatureWithPublicKey,
  }) async {
    await chain.holdSignedSubmit?.future;
    final hash = await chain.submit();
    chain.signedTransfers.add((
      from: account.accountId,
      recipient: targetAddress,
      amount: amount,
      fee: fee,
      unsigned: unsignedData,
      signature: signatureWithPublicKey,
    ));
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

  Future<String> _action(String action, Account signer, BigInt? fee, List<int>? callBytes) async {
    final hash = await chain.submitAction();
    chain.actions.add((action, signer.accountId, fee, callBytes));
    return hash;
  }

  @override
  Future<String> approveProposal({
    required MultisigAccount msig,
    required Account signer,
    required MultisigProposal proposal,
    List<int>? callBytes,
  }) => _action('approve', signer, null, callBytes);

  @override
  Future<String> executeProposal({
    required MultisigAccount msig,
    required Account signer,
    required MultisigProposal proposal,
    List<int>? callBytes,
    BigInt? fee,
  }) => _action('execute', signer, fee, callBytes);

  @override
  Future<String> cancelProposal({
    required MultisigAccount msig,
    required Account proposer,
    required MultisigProposal proposal,
    BigInt? fee,
  }) => _action('cancel', proposer, fee, null);
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
    device._wipeStorage();
  }
}

/// A device and a chain for the flows that create, import or wipe a wallet.
/// It starts with no wallet. Every balance is [balance].
class FakeWalletDevice {
  final storage = FakeWalletStorage();

  /// The chain as Send reaches it.
  final chain = FakeSendChain();

  /// 1Click as a followed swap asks it.
  final swaps = FakeSwapService();

  /// What every transparent account holds.
  BigInt balance = oneToken;

  /// What the app is told it may offer.
  RemoteConfigModel remoteConfig = RemoteConfigModel.defaults;

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

  /// Wipes through the real [LogoutService], for a test of what it resets.
  bool realLogout = false;

  void _wipeStorage() => storage
    ..accounts.clear()
    ..mnemonics.clear()
    ..pendingScans.clear()
    ..bools.clear()
    ..strings.clear()
    ..activeAccount = null;

  /// Puts a software wallet with [accounts] on the device.
  void store(List<Account> accounts, {String? mnemonic = 'a stored recovery phrase'}) {
    storage.accounts.addAll(accounts);
    storage.activeAccount = RegularAccount(accounts.first);
    if (mnemonic != null) storage.mnemonics[accounts.first.walletIndex] = mnemonic;
  }

  List<Override> get overrides => [
    settingsServiceProvider.overrideWithValue(storage),
    swapServiceProvider.overrideWithValue(swaps),
    // No logo is fetched: the marks are their letters.
    swapTokenIconServiceProvider.overrideWithValue(FakeSwapTokenIcons()),
    accountsServiceProvider.overrideWithValue(_StoredAccountsService(storage)),
    hdWalletServiceProvider.overrideWithValue(_FakeHdWalletService()),
    substrateServiceProvider.overrideWithValue(_FakeSubstrateService(chain, device: this)),
    ...chain.overrides(substrate: false),
    accountDiscoveryServiceProvider.overrideWithValue(_FakeAccountDiscoveryService(this)),
    if (!realLogout) logoutServiceProvider.overrideWithValue(_WipingLogoutService(this)),
    remoteConfigProvider.overrideWith((ref) => RemoteConfigNotifier(FakeRemoteConfigService(remoteConfig))),
    balanceProviderFamily.overrideWith((ref, accountId) => balance),
    encryptedBalanceProvider.overrideWith(
      (ref, walletIndex) =>
          AsyncValue.data(encryptedDeposits.isEmpty ? oneToken : _encryptedState(walletIndex).balance),
    ),
    encryptedStateProvider.overrideWith((ref, walletIndex) {
      final held = holdEncryptedState;
      if (held == null) return _encryptedState(walletIndex);
      return held.future.then((_) => _encryptedState(walletIndex));
    }),
  ];

  /// When set, reading an Encrypted account waits for it.
  Completer<void>? holdEncryptedState;

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

  /// What the server answers when asked; nothing new until a test says so.
  RemoteConfigModel? remote;

  /// How often the server was asked.
  int reads = 0;

  @override
  RemoteConfigModel readLocalConfig() => config;

  @override
  Future<RemoteConfigModel?> readRemoteConfig() async {
    reads++;
    return remote;
  }

  @override
  Future<void> cacheConfig(Object json) async {}
}

/// The flags where swaps are not allowed.
const swapsNotOffered = RemoteConfigModel(
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
/// approves; Send reaches the chain through [chain]. Where swaps are allowed
/// is read from [remoteConfig], or as [swapAvailable] says. 1Click is [swaps],
/// or what [swapsOf] builds, for a test that has the service rebuilt.
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
  FakeSwapService? swaps,
  FakeSwapService Function(Ref ref)? swapsOf,
  FakeRemoteConfigService? remoteConfig,
  Completer<void>? Function()? holdEncryptedState,
}) {
  return [
    if (swapsOf != null)
      swapServiceProvider.overrideWith(swapsOf)
    else
      swapServiceProvider.overrideWithValue(swaps ?? FakeSwapService()),
    // No logo is fetched: the marks are their letters.
    swapTokenIconServiceProvider.overrideWithValue(FakeSwapTokenIcons()),
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
      // Read for the Encrypted account's activity: it has none. A read waits
      // for what [holdEncryptedState] answers at the time, when it is set.
      encryptedStateProvider.overrideWith((ref, walletIndex) {
        final held = holdEncryptedState?.call();
        if (held == null) return emptyEncryptedState(walletIndex);
        return held.future.then((_) => emptyEncryptedState(walletIndex));
      }),
    settingsServiceProvider.overrideWithValue(settings ?? FakeSettingsService()),
    accountsServiceProvider.overrideWithValue(FakeAccountsService(loadAccounts ?? () async => accounts)),
    remoteConfigProvider.overrideWith(
      (ref) => RemoteConfigNotifier(
        remoteConfig ?? FakeRemoteConfigService(swapAvailable ? RemoteConfigModel.defaults : swapsNotOffered),
      ),
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

/// 1Click as far as the app asks it: what it lists, what a swap would cost,
/// a live order for one, and how a followed swap is doing.
class FakeSwapService extends Fake implements SwapService {
  /// What the next status poll answers for the order it is asked about; it
  /// may throw. The order as it stands until a test says otherwise.
  Future<SwapOrder> Function(SwapOrder order) status = (order) async => order;

  /// How often the status was asked for.
  int polls = 0;

  @override
  Future<SwapOrder> getSwapStatus(SwapOrder order) {
    polls++;
    return status(order);
  }

  /// What 1Click lists, QTC first; listing may throw.
  Future<List<SwapToken>> Function() tokens = () async => const [
    listedQtc,
    usdcOnArbitrum,
    usdcOnEthereum,
    usdtOnEthereum,
    wNear,
  ];

  /// QTC as 1Click lists it; null while it does not, or lists it unpriced.
  SwapToken? listedQuantus = listedQtc;

  /// How often the listing was asked for, and how often afresh.
  int tokenLoads = 0;
  int freshTokenLoads = 0;

  @override
  Future<List<SwapToken>> getFromTokens({bool forceRefresh = false}) {
    tokenLoads++;
    if (forceRefresh) freshTokenLoads++;
    return tokens();
  }

  @override
  Future<SwapToken?> getListedQuantusToken() async => listedQuantus;

  /// What a dry quote answers for the swap asked about; it may throw. One at
  /// listed prices, with nothing taken, until a test says otherwise.
  Future<SwapQuote> Function(SwapQuoteRequest request) quote = (request) async => fakeQuoteFor(request);

  /// Every swap a dry quote was asked for, in order.
  final quoteRequests = <SwapQuoteRequest>[];

  @override
  Future<SwapQuote> getQuote({
    required SwapToken from,
    required SwapToken to,
    required BigInt amount,
    required String refundAddress,
    required String recipient,
    SwapType swapType = SwapType.exactInput,
    int slippageBps = SwapService.defaultSlippageBps,
    bool dry = true,
  }) {
    final request = (
      from: from,
      to: to,
      amount: amount,
      swapType: swapType,
      refundAddress: refundAddress,
      recipient: recipient,
      slippageBps: slippageBps,
    );
    quoteRequests.add(request);
    return quote(request);
  }

  /// What taking a live order for a reviewed quote answers; it may throw.
  /// The quote as reviewed, awaiting its deposit, until a test says otherwise.
  Future<SwapOrder> Function(SwapQuote reviewed) create = (reviewed) async =>
      SwapOrder(quote: reviewed, status: SwapStatus.pendingDeposit);

  /// Every quote a live order was taken for, in order.
  final created = <SwapQuote>[];

  @override
  Future<SwapOrder> createSwap(SwapQuote quote) {
    created.add(quote);
    return create(quote);
  }

  /// The addresses saved for each network, most recent first.
  final saved = <String, List<String>>{};

  /// When set, reading the saved addresses, saving one or removing one fails
  /// with it.
  Object? savedReadError;
  Object? saveError;
  Object? removeError;

  @override
  Future<List<String>> getSavedAddresses(String network) async {
    if (savedReadError case final error?) throw error;
    return [...?saved[network]];
  }

  @override
  Future<void> saveAddress(String network, String address) async {
    if (saveError case final error?) throw error;
    saved[network] = [address, ...?saved[network]?.where((a) => a != address)];
  }

  /// When set, a removal waits for it before it answers.
  Completer<void>? removeHold;

  @override
  Future<void> removeSavedAddress(String network, String address) async {
    await removeHold?.future;
    if (removeError case final error?) throw error;
    saved[network] = [...?saved[network]?.where((a) => a != address)];
  }

  /// Every deposit 1Click was told of: the order and the transaction's hash.
  final deposits = <({SwapOrder order, String hash})>[];

  @override
  Future<void> submitDeposit(SwapOrder order, String txHash) async => deposits.add((order: order, hash: txHash));
}

/// Where 1Click takes the QTC of a swap out of it: an address on Quantus.
const swapQuantusDepositAddress = 'qzSwapDeposit';

/// A dry quote for [request] at listed prices, nothing taken by fees: its
/// deposit goes within twenty minutes to [swapQuantusDepositAddress] when QTC
/// is paid, else to [swapDepositAddress] on the other chain.
SwapQuote fakeQuoteFor(SwapQuoteRequest request, {BigInt? withdrawFee, int feeBps = 0, DateTime? deadline}) {
  final exactOutput = request.swapType == SwapType.exactOutput;
  final amountIn = exactOutput ? swapEstimateOut(request.amount, request.to, request.from) : request.amount;
  final amountOut = exactOutput ? request.amount : swapEstimateOut(request.amount, request.from, request.to);
  final kept = BigInt.from(10000 - request.slippageBps);
  final all = BigInt.from(10000);
  return SwapQuote(
    fromToken: request.from,
    toToken: request.to,
    swapType: request.swapType,
    amountIn: exactOutput ? amountIn * all ~/ kept : amountIn,
    minAmountIn: amountIn,
    amountOut: amountOut,
    minAmountOut: exactOutput ? amountOut : amountOut * kept ~/ all,
    amountInUsd: swapUsdValue(amountIn, request.from),
    amountOutUsd: swapUsdValue(amountOut, request.to),
    slippageBps: request.slippageBps,
    refundAddress: request.refundAddress,
    recipient: request.recipient,
    deadline: deadline ?? clock.now().add(const Duration(minutes: 20)),
    timeEstimate: const Duration(minutes: 3),
    correlationId: 'c',
    signature: 's',
    depositAddress: request.from.isQuantus ? swapQuantusDepositAddress : swapDepositAddress,
    withdrawFee: withdrawFee,
    feeBps: feeBps,
  );
}

/// Token and chain logos that are never there, so nothing is fetched.
class FakeSwapTokenIcons extends Fake implements SwapTokenIconService {
  @override
  Future<SwapTokenIcon?> iconFor(SwapToken token) async => null;

  @override
  Future<SwapTokenIcon?> imageAt(String url) async => null;
}

const usdcOnArbitrum = SwapToken(
  assetId: 'nep141:arb-usdc.omft.near',
  symbol: 'USDC',
  network: 'ARB',
  decimals: 6,
  usdPrice: 1,
);
const usdcOnEthereum = SwapToken(
  assetId: 'nep141:eth-usdc.omft.near',
  symbol: 'USDC',
  network: 'ETH',
  decimals: 6,
  usdPrice: 1,
);
const usdtOnEthereum = SwapToken(
  assetId: 'nep141:eth-usdt.omft.near',
  symbol: 'USDT',
  network: 'ETH',
  decimals: 6,
  usdPrice: 1,
);
const wNear = SwapToken(assetId: 'nep141:wrap.near', symbol: 'wNEAR', network: 'NEAR', decimals: 24, usdPrice: 2.5);
const listedQtc = SwapToken(
  assetId: 'nep141:qtc.omft.near',
  symbol: 'QTC',
  network: SwapToken.quantusNetwork,
  decimals: AppConstants.decimals,
  usdPrice: 0.4188,
  isQuantus: true,
);
const swapRecipient = '0x3EC8b9CD4a7e21F05c6D8B93aE7f12C4d6A1509f';
const swapDepositAddress = '0x8F41c2B7e9A05d36C1f4E8a27B90d5C3e6F7A214';
const swapDepositTx = '0x7f3c9a1e5b2d48c6a0f19e3b7d5c2a8e4f6b1d9c3a7e5f2b8d4c6a1e9f3b7d50';

/// A live quote: 250 QTC out of [account] for 104.37 USDC on Arbitrum at
/// [swapRecipient], or, the other way, 100 USDC from outside for 236.9 QTC
/// into it, refunded at [swapRecipient]. Its deposit goes to
/// [depositAddress] by [deadline], twenty minutes from now unless said.
SwapQuote fakeSwapQuote({
  bool swapOut = true,
  Account account = mainAccount,
  DateTime? deadline,
  String depositAddress = swapDepositAddress,
  String? depositMemo,
}) => SwapQuote(
  fromToken: swapOut ? listedQtc : usdcOnArbitrum,
  toToken: swapOut ? usdcOnArbitrum : listedQtc,
  amountIn: swapOut ? oneToken * BigInt.from(250) : BigInt.from(100000000),
  minAmountIn: swapOut ? oneToken * BigInt.from(250) : BigInt.from(100000000),
  amountOut: swapOut ? BigInt.from(104370000) : oneToken * BigInt.from(2369) ~/ BigInt.from(10),
  minAmountOut: swapOut ? BigInt.from(103330000) : oneToken * BigInt.from(2345) ~/ BigInt.from(10),
  amountInUsd: 104.7,
  amountOutUsd: 104.37,
  slippageBps: 100,
  refundAddress: swapOut ? account.accountId : swapRecipient,
  recipient: swapOut ? swapRecipient : account.accountId,
  deadline: deadline ?? clock.now().add(const Duration(minutes: 20)),
  timeEstimate: const Duration(minutes: 3),
  correlationId: 'c',
  signature: 's',
  depositAddress: depositAddress,
  depositMemo: depositMemo,
);

/// A swap as it is followed, started [age] ago from [account]: the app sent
/// a swap out's deposit, a swap in waits for one made by hand, [depositSent]
/// once that was marked sent. Swaps followed together each need a
/// [depositAddress] of their own: it is what tells them apart.
ActiveSwap fakeActiveSwap({
  bool swapOut = true,
  SwapStatus status = SwapStatus.knownDepositTx,
  Account account = mainAccount,
  Duration age = const Duration(minutes: 3, seconds: 7),
  DateTime? deadline,
  String depositAddress = swapDepositAddress,
  String? depositMemo,
  bool depositSent = false,
  BigInt? amountOut,
  String? refundReason,
  String? pollError,
}) {
  final now = clock.now();
  return ActiveSwap(
    order: SwapOrder(
      quote: fakeSwapQuote(
        swapOut: swapOut,
        account: account,
        deadline: deadline,
        depositAddress: depositAddress,
        depositMemo: depositMemo,
      ),
      status: status,
      amountOut: amountOut,
      refundReason: refundReason,
    ),
    accountId: account.accountId,
    accountName: account.name,
    startedAt: now.subtract(age),
    settledAt: status.isFinal ? now : null,
    depositByHand: !swapOut,
    depositSent: depositSent,
    depositTxHash: swapOut ? swapDepositTx : null,
    depositFee: swapOut ? FakeSendChain.usualFee : null,
    pollError: pollError,
  );
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
  FakeEncryptedAccountService(this.nextAddress, {this.ownAddresses = const {}, this.innerHash});

  final Future<String> Function() nextAddress;
  final Set<String> ownAddresses;

  /// The account's inner hash; reading it waits for, or fails with, what this
  /// returns. Without it the inner hash is empty.
  final Future<String> Function()? innerHash;

  @override
  Future<bool> ownsAddress(String address) async => ownAddresses.contains(address);

  @override
  Future<WormholeKeyPair> receiveKeyPair() async => WormholeKeyPair(
    address: await nextAddress(),
    addressHex: '',
    rewardsPreimageHex: await (innerHash ?? () async => '')(),
    secretHex: '',
  );
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
///
/// The system's notifications are always a fake one: [notifications] when a
/// test looks at them.
Future<void> pumpShell(
  WidgetTester tester, {
  required List<Override> overrides,
  FakeLoginPassword? loginPassword,
  FakeHistoryPollingManager? polling,
  bool realPolling = false,
  FakeNetwork? network,
  FakeNotificationPlugin? notifications,
  FakeBackgroundWindow? backgroundWindow,
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
        notificationPluginProvider.overrideWithValue(notifications ?? FakeNotificationPlugin()),
        // Never the Mac's own push service: a build not signed to receive
        // pushes, which registers nothing.
        macPushProvider.overrideWithValue(FakeMacPush(environmentOfBuild: null)),
        backgroundWindowProvider.overrideWithValue(backgroundWindow ?? FakeBackgroundWindow()),
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

/// The bytes of a real runtime call from quantus_sdk's sample calls, by its
/// name there (e.g. `ReversibleTransfers.set_high_security`), as a
/// proposal's `callRaw` carries them.
Uint8List corpusCall(String name) {
  final hex = callCorpus[name] ?? (throw ArgumentError.value(name, 'name', 'not a sample call'));
  return Uint8List.fromList([for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);
}
