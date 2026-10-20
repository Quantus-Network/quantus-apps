/// Fixtures shared by the SDK's and the apps' tests.
library;

import 'dart:typed_data';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/services/remote_config_service.dart';

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
