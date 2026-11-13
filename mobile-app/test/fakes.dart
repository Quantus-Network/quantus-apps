import 'dart:async';

import 'package:flutter/services.dart';
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
import 'package:resonance_network_wallet/services/history_polling_manager.dart';
import 'package:resonance_network_wallet/services/remote_config_service.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/wallet_core_overrides.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';

class FakeSettingsService extends Fake implements SettingsService {
  DisplayAccount? activeAccount;
  List<MultisigAccount> multisigs;
  bool hasWallet = true;
  ActiveSwap? activeSwap;

  FakeSettingsService({this.activeAccount, this.multisigs = const [], this.activeSwap});

  @override
  Future<bool> getHasWallet() async => hasWallet;

  @override
  Future<DisplayAccount?> getActiveAccount() async => activeAccount;

  @override
  Future<void> setActiveAccount(DisplayAccount account) async => activeAccount = account;

  @override
  Future<List<MultisigAccount>> getMultisigAccounts() async => multisigs;

  @override
  Future<void> addMultisigAccount(MultisigAccount account) async => multisigs = [...multisigs, account];

  @override
  String? getSelectedAppLocale() => 'en';

  @override
  String? getSelectedFiatCurrency() => null;

  @override
  Future<void> clearSelectedAppLocale() async {}

  @override
  Future<void> clearSelectedFiatCurrency() async {}

  bool balanceHidden = false;

  @override
  bool isBalanceHidden() => balanceHidden;

  @override
  Future<void> setBalanceHidden(bool value) async => balanceHidden = value;

  @override
  bool isCurrencyFlipped() => false;

  @override
  String? getWalletName(int walletIndex) => null;

  @override
  AirdropClaimRecord? getAirdropClaim(int walletIndex) => null;

  @override
  String? getString(String key) => null;

  @override
  ActiveSwap? getActiveSwap() => activeSwap;

  @override
  Future<void> setActiveSwap(ActiveSwap swap) async => activeSwap = swap;

  @override
  Future<void> clearActiveSwap() async => activeSwap = null;
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
  int feeCalls = 0;
  int logoutCalls = 0;
  Account? lastFeeAccount;
  RuntimeCall? lastFeeCall;

  @override
  bool isValidSS58Address(String address) => true;

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<ExtrinsicFeeData> getFeeForCall(Account account, RuntimeCall call) async {
    feeCalls++;
    lastFeeAccount = account;
    lastFeeCall = call;
    return ExtrinsicFeeData(fee: fee, blockHash: '0x00', blockNumber: 1);
  }
}

class FakeRecentAddressesService extends Fake implements RecentAddressesService {
  @override
  Future<List<String>> getAddresses() async => [];
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
///
/// wallet_core's platform seams are bound with [testWalletCoreOverrides]
/// unless [walletCore] replaces them.
Future<WidgetRef> pumpRef(
  WidgetTester tester, {
  List<Override> overrides = const [],
  List<Override>? walletCore,
}) async {
  late WidgetRef widgetRef;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...walletCore ?? testWalletCoreOverrides(), ...overrides],
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

/// Stands in for TelemetryDeck's platform channel, which tests do not have,
/// and collects every call made on it.
List<MethodCall> recordTelemetry() {
  final calls = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('telemetrydecksdk'),
    (call) async => calls.add(call),
  );
  return calls;
}

/// Records every push registration call instead of reaching the push backend.
class FakePushRegistration implements PushRegistration {
  final calls = <String>[];

  /// When set, every call fails with it.
  Object? failure;

  @override
  Future<void> registerDevice() async => _record('registerDevice');

  @override
  Future<void> registerAddress(String address) async => _record('registerAddress($address)');

  @override
  Future<void> unregister() async => _record('unregister');

  void _record(String call) {
    if (failure case final failure?) throw failure;
    calls.add(call);
  }
}

/// Collects the notifications handed over for display.
class FakeLocalNotifications implements LocalNotifications {
  final shown = <NotificationData>[];

  @override
  Future<void> showOrScheduleNotification(NotificationData notification) async => shown.add(notification);
}

/// Collects event and error names instead of sending them.
class FakeTelemetry implements Telemetry {
  final events = <String>[];
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) => events.add(eventName);

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

/// Binds wallet_core's platform seams for a test scope.
///
/// Telemetry defaults to the app's [TelemetryService], so tests that assert on
/// its channel through [recordTelemetry] see what production would send. Push
/// and local notifications default to fakes: their real implementations need
/// Firebase and the notification plugin.
List<Override> testWalletCoreOverrides({
  Telemetry? telemetry,
  PushRegistration? pushRegistration,
  LocalNotifications? localNotifications,
}) => walletCoreOverrides(
  telemetry: (_) => telemetry ?? TelemetryService(),
  pushRegistration: (_) => pushRegistration ?? FakePushRegistration(),
  localNotifications: (_) => localNotifications ?? FakeLocalNotifications(),
);
