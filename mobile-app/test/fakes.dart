import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';

class FakeSettingsService extends Fake implements SettingsService {
  DisplayAccount? activeAccount;
  List<MultisigAccount> multisigs;

  FakeSettingsService({this.activeAccount, this.multisigs = const []});

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

  final BigInt fee;
  Account? lastFeeAccount;

  @override
  bool isValidSS58Address(String address) => true;

  @override
  Future<ExtrinsicFeeData> getFeeForCall(Account account, RuntimeCall call) async {
    lastFeeAccount = account;
    return ExtrinsicFeeData(fee: fee, blockHash: '0x00', blockNumber: 1);
  }
}

class FakeHumanReadableChecksumService extends Fake implements HumanReadableChecksumService {
  FakeHumanReadableChecksumService({this.phrase = 'Stand-Envelope-Topic-Term-Help'});

  final String phrase;

  @override
  Future<String?> getHumanReadableName(String address, {upperCase = true}) async => phrase;
}

class FakeBalancesService extends Fake implements BalancesService {
  @override
  Balances getBalanceTransferCall(String targetAddress, BigInt amount) => const balances_pallet.Txs()
      .transferAllowDeath(dest: const multi_address.$MultiAddress().id(List<int>.filled(32, 0)), value: amount);
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
