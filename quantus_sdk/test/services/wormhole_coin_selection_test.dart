import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

WormholeUtxo utxo(int scaled) => WormholeUtxo(
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

BigInt tokens(String v) => wormholeTokenFromScaled((double.parse(v) * 100).round());

void main() {
  test('uses the live runtime volume fee', () {
    expect(wormholeVolumeFeeBps, 4);
    expect(wormholeVolumeFeePercentText(), '0.04');
    expect(wormholeNetScaled(2500), 2499);
    expect(wormholeBatchOutputs(List.filled(7, 50)), [50, 50, 50, 50, 50, 50, 49]);
  });

  group('selectWormholeInputs', () {
    test('plan worked example: 10 tokens from 1.1 + 5.8 + 4.0', () {
      final plan = selectWormholeInputs(utxos: [utxo(110), utxo(580), utxo(400)], amountToken: tokens('10'));

      expect(plan.inputCount, 3);
      expect(plan.batches.length, 1);
      expect(plan.amountToken, tokens('10'));
      expect(plan.changeToken, tokens('0.89'));
      expect(plan.feeToken, tokens('0.01'));

      final recipientTotal = plan.batches[0].fold<int>(0, (s, a) => s + a.recipientScaled);
      expect(wormholeTokenFromScaled(recipientTotal), tokens('10'));
      expect(plan.batches[0].where((a) => a.changeScaled > 0).length, 1);
      final inputs = plan.batches[0].map((a) => wormholeScaledFromToken(a.utxo.amount));
      expect(plan.batches[0].fold<int>(0, (sum, a) => sum + a.exitScaled), wormholeBatchNetScaled(inputs));
    });

    test('splits across batches beyond 7 inputs, change appears once', () {
      final plan = selectWormholeInputs(utxos: List.generate(9, (_) => utxo(200)), amountToken: tokens('16'));

      // Seven inputs net 13.99; eight net 15.98, so the ninth is required.
      expect(plan.inputCount, 9);
      expect(plan.batches.length, 2);
      expect(plan.batches.every((b) => b.length <= 7), isTrue);
      expect(plan.batches.expand((b) => b).where((a) => a.changeScaled > 0).length, 1);
      expect(plan.changeToken, tokens('1.98'));
      expect(plan.feeToken, tokens('0.02'));
    });

    test('insufficient funds reports exact max sendable', () {
      final e = throwsA(
        isA<InsufficientEncryptedFunds>().having((e) => e.maxSendableToken, 'maxSendable', tokens('1.99')),
      );
      expect(() => selectWormholeInputs(utxos: [utxo(100), utxo(100)], amountToken: tokens('2')), e);
    });

    test('rejects non-quantized amounts', () {
      expect(
        () => selectWormholeInputs(utxos: [utxo(1000)], amountToken: tokens('1') + BigInt.one),
        throwsArgumentError,
      );
    });

    test('allows sub-0.1 exits because the chain has no separate minimum', () {
      final plan = selectWormholeInputs(utxos: [utxo(9)], amountToken: wormholeTokenFromScaled(8));
      expect(plan.amountToken, wormholeTokenFromScaled(8));
      expect(plan.feeToken, wormholeTokenFromScaled(1));
    });

    test('wormholeMaxSendable deducts one fee per batch', () {
      expect(wormholeMaxSendable([utxo(110), utxo(580), utxo(400)]), tokens('10.89'));
      expect(wormholeMaxSendable(List.generate(7, (_) => utxo(50))), tokens('3.49'));
    });

    test('exactly 7 inputs fit in a single batch', () {
      final plan = selectWormholeInputs(utxos: List.generate(7, (_) => utxo(200)), amountToken: tokens('12'));
      expect(plan.inputCount, 7);
      expect(plan.batches.length, 1);
      expect(plan.batches[0].length, 7);
      final recipientTotal = plan.batches[0].fold<int>(0, (s, a) => s + a.recipientScaled);
      expect(wormholeTokenFromScaled(recipientTotal), tokens('12'));
    });

    test('send max: all input nets consumed with zero change', () {
      final inputs = [utxo(110), utxo(580), utxo(400)];
      final maxSendable = wormholeMaxSendable(inputs);
      final plan = selectWormholeInputs(utxos: inputs, amountToken: maxSendable);
      expect(plan.amountToken, maxSendable);
      expect(plan.changeToken, BigInt.zero);
      final totalChange = plan.batches.expand((b) => b).fold<int>(0, (s, a) => s + a.changeScaled);
      expect(totalChange, 0);
    });
  });
}
