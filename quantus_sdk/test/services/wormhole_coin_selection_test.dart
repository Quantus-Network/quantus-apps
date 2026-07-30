import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

WormholeUtxo utxo(int scaled) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: 't$scaled',
    blockHeight: 1,
    fromId: 'from',
    toId: 'to',
    amount: wormholeRawFromScaled(scaled),
    toHash: '0x00',
    leafIndex: BigInt.from(scaled),
    transferCount: BigInt.one,
  ),
  owner: const WormholeAddressInfo(index: 0, address: 'addr', secretHex: '0x00'),
  nullifierHex: '0xn$scaled',
);

BigInt tokens(String v) => wormholeRawFromScaled((double.parse(v) * 100).round());

void main() {
  group('selectWormholeInputs', () {
    test('plan worked example: 10 tokens from 1.1 + 5.8 + 4.0', () {
      final plan = selectWormholeInputs(utxos: [utxo(110), utxo(580), utxo(400)], amountRaw: tokens('10'));

      expect(plan.inputCount, 3);
      expect(plan.batches.length, 1);
      expect(plan.amountRaw, tokens('10'));
      expect(plan.changeRaw, tokens('0.87'));
      expect(plan.feeRaw, tokens('0.03'));

      final recipientTotal = plan.batches[0].fold<int>(0, (s, a) => s + a.recipientScaled);
      expect(wormholeRawFromScaled(recipientTotal), tokens('10'));
      expect(plan.batches[0].where((a) => a.changeScaled > 0).length, 1);
      for (final a in plan.batches[0]) {
        final net = wormholeNetScaled(wormholeScaledFromRaw(a.utxo.amount));
        expect(a.recipientScaled + a.changeScaled, net);
      }
    });

    test('splits across batches beyond 7 inputs, change appears once', () {
      final plan = selectWormholeInputs(utxos: List.generate(9, (_) => utxo(200)), amountRaw: tokens('16'));

      // 200 nets 199; 9 inputs net 17.91 total, 8 inputs net 15.92 < 16.
      expect(plan.inputCount, 9);
      expect(plan.batches.length, 2);
      expect(plan.batches.every((b) => b.length <= 7), isTrue);
      expect(plan.batches.expand((b) => b).where((a) => a.changeScaled > 0).length, 1);
      for (final batch in plan.batches) {
        final exit = batch.fold<int>(0, (s, a) => s + a.exitScaled);
        expect(exit, greaterThanOrEqualTo(wormholeMinBatchExitScaled));
      }
      expect(plan.changeRaw, tokens('1.91'));
    });

    test('insufficient funds reports exact max sendable', () {
      final e = throwsA(
        isA<InsufficientEncryptedFunds>().having((e) => e.maxSendableRaw, 'maxSendable', tokens('1.98')),
      );
      expect(() => selectWormholeInputs(utxos: [utxo(100), utxo(100)], amountRaw: tokens('2')), e);
    });

    test('rejects non-quantized amounts', () {
      expect(
        () => selectWormholeInputs(utxos: [utxo(1000)], amountRaw: tokens('1') + BigInt.one),
        throwsArgumentError,
      );
    });

    test('rejects a batch below the chain minimum exit', () {
      expect(
        () => selectWormholeInputs(utxos: [utxo(9)], amountRaw: wormholeRawFromScaled(8)),
        throwsA(isA<BatchBelowMinimumExit>()),
      );
    });

    test('wormholeMaxSendable sums per-input nets', () {
      expect(wormholeMaxSendable([utxo(110), utxo(580), utxo(400)]), tokens('10.87'));
    });

    test('exactly 7 inputs fit in a single batch', () {
      final plan = selectWormholeInputs(utxos: List.generate(7, (_) => utxo(200)), amountRaw: tokens('12'));
      expect(plan.inputCount, 7);
      expect(plan.batches.length, 1);
      expect(plan.batches[0].length, 7);
      final recipientTotal = plan.batches[0].fold<int>(0, (s, a) => s + a.recipientScaled);
      expect(wormholeRawFromScaled(recipientTotal), tokens('12'));
    });

    test('send max: all input nets consumed with zero change', () {
      final inputs = [utxo(110), utxo(580), utxo(400)];
      final maxSendable = wormholeMaxSendable(inputs);
      final plan = selectWormholeInputs(utxos: inputs, amountRaw: maxSendable);
      expect(plan.amountRaw, maxSendable);
      expect(plan.changeRaw, BigInt.zero);
      final totalChange = plan.batches.expand((b) => b).fold<int>(0, (s, a) => s + a.changeScaled);
      expect(totalChange, 0);
    });
  });
}
