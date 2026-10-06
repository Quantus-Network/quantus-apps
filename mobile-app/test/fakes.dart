import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/pallet_balances/pallet/call.dart' as balances_call;
import 'package:quantus_sdk/generated/bell/types/quantus_runtime/runtime_call.dart' as runtime_call;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/history_polling_manager.dart';
import 'package:resonance_network_wallet/services/remote_config_service.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';

class FakeSettingsService extends Fake implements SettingsService {
  DisplayAccount? activeAccount;
  List<MultisigAccount> multisigs;
  bool hasWallet = true;

  FakeSettingsService({this.activeAccount, this.multisigs = const []});

  @override
  Future<bool> getHasWallet() async => hasWallet;

  @override
  Future<DisplayAccount?> getActiveAccount() async => activeAccount;

  @override
  Future<void> setActiveAccount(DisplayAccount account) async => activeAccount = account;

  @override
  Future<List<MultisigAccount>> getMultisigAccounts() async => multisigs;

  @override
  String? getSelectedAppLocale() => 'en';

  @override
  String? getSelectedFiatCurrency() => null;

  @override
  bool isBalanceHidden() => false;

  @override
  bool isCurrencyFlipped() => false;

  @override
  String? getWalletName(int walletIndex) => null;

  @override
  AirdropClaimRecord? getAirdropClaim(int walletIndex) => null;

  @override
  String? getString(String key) => null;
}

/// The platform auth plugin without a platform: answers [authenticateResult],
/// or waits for [hold] when a test needs the prompt to stay up.
class FakeLocalAuthentication extends Fake implements LocalAuthentication {
  bool deviceSupported = true;
  bool authenticateResult = true;
  int authenticateCalls = 0;
  Future<bool>? hold;

  /// Invoked from inside [authenticate], i.e. while the "prompt" is on screen.
  /// Lets a test observe transient state (e.g. isAuthenticating) mid-call, or
  /// throw to simulate a platform failure.
  void Function()? onAuthenticate;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const <dynamic>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCalls++;
    onAuthenticate?.call();
    return hold ?? authenticateResult;
  }
}

class FakeHistoryPollingManager extends Fake implements HistoryPollingManager {
  @override
  void pausePolling() {}

  @override
  void resumePolling() {}

  @override
  Future<void> triggerSilentRefresh() async {}
}

/// Drives [LocalAuthState] directly so tests can lock/unlock without the
/// platform auth dialog.
class TestLocalAuthController extends LocalAuthController {
  TestLocalAuthController({required bool authenticated}) : super(LocalAuthService()) {
    setAuthenticated(authenticated);
  }

  void setAuthenticated(bool value) {
    state = state.copyWith(isAuthenticated: value);
  }

  void setVisuallyLocked(bool value) {
    state = state.copyWith(isVisuallyLocked: value);
  }
}

class FakeSubstrateService extends Fake implements SubstrateService {
  FakeSubstrateService({BigInt? fee}) : fee = fee ?? BigInt.one;

  BigInt fee;

  /// When set, prices a plain transfer by its amount instead of [fee].
  BigInt Function(BigInt amount)? feeForAmount;

  /// When set, every fee answer waits for this first.
  Future<void>? hold;
  int feeCalls = 0;
  Account? lastFeeAccount;
  RuntimeCall? lastFeeCall;

  @override
  bool isValidSS58Address(String address) => true;

  @override
  Future<ExtrinsicFeeData> getFeeForCall(Account account, RuntimeCall call) async {
    feeCalls++;
    lastFeeAccount = account;
    lastFeeCall = call;
    await hold;
    final amount = transferAmount(call);
    final priced = amount != null && feeForAmount != null ? feeForAmount!(amount) : fee;
    return ExtrinsicFeeData(fee: priced, blockHash: '0x00', blockNumber: 1);
  }
}

/// Amount of a `Balances.transfer_allow_death` [call]; null for any other call.
BigInt? transferAmount(RuntimeCall call) {
  if (call is! runtime_call.Balances) return null;
  final inner = call.value0;
  return inner is balances_call.TransferAllowDeath ? inner.value : null;
}

/// Remote config that allows Max to send with `transfer_all`.
final transferAllOn = RemoteConfigModel.fromJson(const {'enableTransferAllCall': true});

/// The remote config as the app sees it: [config] cached and served again.
Override remoteConfigOverride(RemoteConfigModel config) =>
    remoteConfigProvider.overrideWith((ref) => RemoteConfigNotifier(FakeRemoteConfigService(config, remote: config)));

class FakeRecentAddressesService extends Fake implements RecentAddressesService {
  @override
  Future<List<String>> getAddresses() async => [];
}

class FakeHumanReadableChecksumService extends Fake implements HumanReadableChecksumService {
  FakeHumanReadableChecksumService({this.phrase = 'Stand-Envelope-Topic-Term-Help'});

  final String phrase;

  @override
  Future<String?> getHumanReadableName(String address, {upperCase = true}) async => phrase;
}

class FakeBalancesService extends Fake implements BalancesService {
  static final _anyDest = const multi_address.$MultiAddress().id(List<int>.filled(32, 0));

  @override
  Balances getBalanceTransferCall(String targetAddress, BigInt amount) =>
      const balances_pallet.Txs().transferAllowDeath(dest: _anyDest, value: amount);

  @override
  Balances getTransferAllCall(String targetAddress) =>
      const balances_pallet.Txs().transferAll(dest: _anyDest, keepAlive: false);
}

/// Whether [call] is `Balances.transfer_all` reaping the sender.
bool isTransferAll(RuntimeCall call) {
  if (call is! runtime_call.Balances) return false;
  final inner = call.value0;
  return inner is balances_call.TransferAll && !inner.keepAlive;
}

Account makeAccount(int index, {AccountType accountType = AccountType.local}) => Account(
  walletIndex: 0,
  index: index,
  name: 'Account $index',
  accountId: 'qzaccount$index${'x' * 40}',
  accountType: accountType,
  scheme: accountType == AccountType.local ? DilithiumSchemeExtension.current : null,
  derivationPath: accountType == AccountType.local
      ? HdWalletService.pathForIndex(index, DilithiumSchemeExtension.current)
      : null,
);

MultisigAccount makeMultisigAccount() => MultisigAccount(
  name: 'Msig',
  accountId: 'qzmsig${'x' * 40}',
  signers: [makeAccount(1).accountId],
  threshold: 1,
  nonce: BigInt.zero,
  myMemberAccountId: makeAccount(1).accountId,
);

UnsignedTransactionData makeUnsignedTransactionData() {
  return UnsignedTransactionData(
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
}

/// Pumps a bare [ProviderScope] and returns a [WidgetRef] bound to it, for
/// exercising code that takes a `WidgetRef` outside a real screen.
Future<WidgetRef> pumpRef(WidgetTester tester, {List<Override> overrides = const []}) async {
  late WidgetRef widgetRef;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) {
          widgetRef = ref;
          return const SizedBox();
        },
      ),
    ),
  );
  return widgetRef;
}

/// Records every local transfer instead of signing and submitting it.
class FakeTransactionSubmissionService extends Fake implements TransactionSubmissionService {
  final transfers = <(String, BigInt, BigInt)>[];

  @override
  Future<String> balanceTransfer(
    Account account, {
    required RuntimeCall call,
    required String targetAddress,
    required BigInt amount,
    required BigInt fee,
  }) async {
    transfers.add((targetAddress, amount, fee));
    return '0xtxhash';
  }
}

class FakeRemoteConfigService extends RemoteConfigService {
  FakeRemoteConfigService(this.config, {this.remote});
  final RemoteConfigModel config;
  RemoteConfigModel? remote;

  /// When set, a remote read answers with this instead of [remote].
  Future<RemoteConfigModel?>? hold;
  int reads = 0;

  @override
  RemoteConfigModel readLocalConfig() => config;

  @override
  Future<RemoteConfigModel?> readRemoteConfig() {
    reads++;
    return hold ?? Future.value(remote);
  }

  @override
  Future<void> cacheConfig(Object json) async {}
}
