import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
  bool isPosModeEnabled() => false;

  @override
  String? getWalletName(int walletIndex) => null;
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
  @override
  bool isValidSS58Address(String address) => true;
}

class FakeHumanReadableChecksumService extends Fake implements HumanReadableChecksumService {
  FakeHumanReadableChecksumService({this.phrase = 'Stand-Envelope-Topic-Term-Help'});

  final String phrase;

  @override
  Future<String?> getHumanReadableName(String address, {upperCase = true}) async => phrase;
}

class FakeBalancesService extends Fake implements BalancesService {
  Account? lastFeeAccount;

  @override
  Future<ExtrinsicFeeData> getBalanceTransferFee(Account account, String targetAddress, BigInt amount) async {
    lastFeeAccount = account;
    return ExtrinsicFeeData(fee: BigInt.from(1000000000), blockHash: '0x00', blockNumber: 1);
  }
}

Account makeAccount(int index, {AccountType accountType = AccountType.local}) => Account(
  walletIndex: 0,
  index: index,
  name: 'Account $index',
  accountId: 'qzaccount$index${'x' * 40}',
  accountType: accountType,
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
