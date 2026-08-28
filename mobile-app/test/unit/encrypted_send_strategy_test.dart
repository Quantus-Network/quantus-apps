import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/encrypted_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

import '../fakes.dart';

WormholeUtxo _utxo(int scaled) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: 't$scaled',
    blockHeight: 1,
    fromId: 'from',
    toId: 'to',
    amount: wormholeTokenFromScaled(scaled),
    toHash: '0x00',
    leafIndex: BigInt.from(scaled),
    transferCount: BigInt.one,
  ),
  owner: const WormholeAddressInfo(index: 0, address: 'addr', secretHex: '0x00'),
  nullifierHex: '0xn$scaled',
);

EncryptedAccountState _state(List<WormholeUtxo> utxos) => EncryptedAccountState(
  utxos: utxos,
  pendingChangeToken: BigInt.zero,
  totalReceivedToken: BigInt.zero,
  changeReceivedToken: BigInt.zero,
  totalSpentToken: BigInt.zero,
  nextIndex: 0,
  nextChangeIndex: 0,
);

void main() {
  final account = makeAccount(1, accountType: AccountType.encrypted);
  final tenTokens = wormholeTokenFromScaled(1000);

  test('fee is the plan over the current UTXO set and survives a background rescan', () async {
    var loads = 0;
    final rescan = Completer<EncryptedAccountState>();
    final container = ProviderContainer(
      overrides: [
        encryptedStateProvider.overrideWith(
          (ref, walletIndex) =>
              ++loads == 1 ? Future.value(_state([_utxo(110), _utxo(580), _utxo(400)])) : rescan.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final strategy = EncryptedSendStrategy(account: account);
    final sub = container.listen(strategy.feeProvider(recipient: 'qz', amount: tenTokens), (_, _) {});

    expect(sub.read().isLoading, isTrue);
    await container.read(encryptedStateProvider(account.walletIndex).future);
    expect((sub.read().requireValue as EncryptedFee).plan?.feeToken, wormholeTokenFromScaled(3));

    container.invalidate(encryptedStateProvider(account.walletIndex));
    expect(sub.read().value?.displayFee, wormholeTokenFromScaled(3));
    expect(loads, 2);
  });

  test('blocks unquantized and unaffordable amounts without a plan', () {
    final utxos = [_utxo(100)];
    expect(planEncryptedFee(utxos, tenTokens + BigInt.one).blocker, EncryptedSendBlocker.notQuantized);
    expect(planEncryptedFee(utxos, tenTokens).blocker, EncryptedSendBlocker.insufficient);
    expect(planEncryptedFee(utxos, BigInt.zero).plan, isNull);
  });
}
