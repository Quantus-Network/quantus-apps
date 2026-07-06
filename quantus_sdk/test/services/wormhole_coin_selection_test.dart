import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

WormholeUtxo utxo(int scaled) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: 't$scaled',
    blockHeight: 1,
    fromId: 'from',
    toId: 'to',
    amount: wormholePlanckFromScaled(scaled),
    toHash: '0x00',
    leafIndex: BigInt.from(scaled),
    transferCount: BigInt.one,
  ),
  owner: const WormholeAddressInfo(index: 0, address: 'addr', secretHex: '0x00'),
  nullifierHex: '0xn$scaled',
);

BigInt quan(String v) => wormholePlanckFromScaled((double.parse(v) * 100).round());

void main() {
  group('selectWormholeInputs', () {
    test('plan worked example: 10 QUAN from 1.1 + 5.8 + 4.0', () {
      final plan = selectWormholeInputs(
        utxos: [utxo(110), utxo(580), utxo(400)],
        amountPlanck: quan('10'),
      );

      expect(plan.inputCount, 3);
      expect(plan.batches.length, 1);
      expect(plan.amountPlanck, quan('10'));
      expect(plan.changePlanck, quan('0.87'));
      expect(plan.feePlanck, quan('0.03'));

      final recipientTotal = plan.batches[0].fold<int>(0, (s, a) => s + a.recipientScaled);
      expect(wormholePlanckFromScaled(recipientTotal), quan('10'));
      expect(plan.batches[0].where((a) => a.changeScaled > 0).length, 1);
      for (final a in plan.batches[0]) {
        final net = wormholeNetScaled(wormholeScaledFromPlanck(a.utxo.amount));
        expect(a.recipientScaled + a.changeScaled, net);
      }
    });

    test('splits across batches beyond 7 inputs, change appears once', () {
      final plan = selectWormholeInputs(
        utxos: List.generate(9, (_) => utxo(200)),
        amountPlanck: quan('16'),
      );

      // 200 nets 199; 9 inputs net 17.91 total, 8 inputs net 15.92 < 16.
      expect(plan.inputCount, 9);
      expect(plan.batches.length, 2);
      expect(plan.batches.every((b) => b.length <= 7), isTrue);
      expect(plan.batches.expand((b) => b).where((a) => a.changeScaled > 0).length, 1);
      for (final batch in plan.batches) {
        final exit = batch.fold<int>(0, (s, a) => s + a.exitScaled);
        expect(exit, greaterThanOrEqualTo(wormholeMinBatchExitScaled));
      }
      expect(plan.changePlanck, quan('1.91'));
    });

    test('insufficient funds reports exact max sendable', () {
      final e = throwsA(
        isA<InsufficientEncryptedFunds>().having((e) => e.maxSendablePlanck, 'maxSendable', quan('1.98')),
      );
      expect(() => selectWormholeInputs(utxos: [utxo(100), utxo(100)], amountPlanck: quan('2')), e);
    });

    test('rejects non-quantized amounts', () {
      expect(
        () => selectWormholeInputs(utxos: [utxo(1000)], amountPlanck: quan('1') + BigInt.one),
        throwsArgumentError,
      );
    });

    test('rejects a batch below the chain minimum exit', () {
      expect(
        () => selectWormholeInputs(utxos: [utxo(9)], amountPlanck: wormholePlanckFromScaled(8)),
        throwsA(isA<BatchBelowMinimumExit>()),
      );
    });

    test('wormholeMaxSendable sums per-input nets', () {
      expect(wormholeMaxSendable([utxo(110), utxo(580), utxo(400)]), quan('10.87'));
    });
  });
}
