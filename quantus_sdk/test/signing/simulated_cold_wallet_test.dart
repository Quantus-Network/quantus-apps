@Tags(['native'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/bell.dart' show Registry;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => RustLib.init());

  test('answers a sign request with a signature the hot side accepts for its own address', () {
    final simulated = SimulatedColdWallet.dev();
    final unsigned = UnsignedTransactionData(
      payloadToSign: QuantusSigningPayload(
        method: Uint8List.fromList([5, 0, 9, 9]),
        specVersion: AppConstants.bundledSpecVersion,
        transactionVersion: AppConstants.bundledTransactionVersion,
        genesisHash: '11' * 32,
        blockHash: '22' * 32,
        blockNumber: 7,
        eraPeriod: 16,
        nonce: 0,
        tip: 0,
      ),
      signer: Uint8List(32),
      registry: Registry(),
    );
    final account = Account(
      walletIndex: 0,
      index: 0,
      name: 'Simulated',
      accountId: simulated.address,
      accountType: AccountType.keystone,
    );
    final response = ColdSignatureResponse.fromUrParts(simulated.signRequest(unsigned));
    response.verifyFor(account, unsigned);
    expect(response.signerAddress, simulated.address);
  });
}
