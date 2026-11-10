import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

WormholeUtxo utxo(int scaled, {String? id}) => WormholeUtxo(
  transfer: WormholeTransfer(
    id: id ?? 't$scaled',
    blockHeight: 1,
    timestamp: DateTime(2026),
    fromId: 'from',
    toId: 'to',
    amount: wormholeTokenFromScaled(scaled),
    toHash: '0x00',
    leafIndex: BigInt.from(scaled),
    transferCount: BigInt.one,
    extrinsicId: '',
    viaWormhole: false,
  ),
  owner: const WormholeAddressInfo(index: 0, address: 'addr', secretHex: '0x00'),
  nullifierHex: '0xn${id ?? scaled}',
);

BigInt tokens(String v) => wormholeTokenFromScaled((double.parse(v) * 100).round());

int inputsScaled(WormholeBatchPlan batch) => batch.inputs.fold(0, (s, u) => s + wormholeScaledFromToken(u.amount));

void main() {
  test('uses the live runtime volume fee', () {
    expect(wormholeVolumeFeeBps, 4);
    expect(wormholeVolumeFeePercentText(), '0.04');
    expect(wormholeNetScaled(2500), 2499);
    expect(wormholeBatchNetScaled(List.filled(7, 50)), 349);
  });

  group('denominateChange', () {
    test('denominations are a descending 1-2-5 series from one token', () {
      final d = wormholeBillDenominationsScaled;
      expect(d.last, wormholeMinBillScaled);
      expect(d.reversed.take(6), [100, 200, 500, 1000, 2000, 5000]);
      expect(d.first, lessThanOrEqualTo(0xFFFFFFFF));
      for (var i = 1; i < d.length; i++) {
        expect(d[i], lessThan(d[i - 1]));
      }
    });

    test('greedy bills plus a sub-bill remainder', () {
      // 1234.56 tokens -> 1000 + 200 + 20 + 10 + 2 + 2 with 0.56 left.
      final (:bills, :remainder) = denominateChange(123456, maxBills: 30);
      expect(bills, [100000, 20000, 2000, 1000, 200, 200]);
      expect(remainder, 56);
      expect(bills.fold(remainder, (s, b) => s + b), 123456);
    });

    test('change below the smallest bill is all remainder', () {
      final small = denominateChange(99, maxBills: 30);
      expect(small.bills, isEmpty);
      expect(small.remainder, 99);
      final none = denominateChange(0, maxBills: 30);
      expect(none.bills, isEmpty);
      expect(none.remainder, 0);
    });

    test('a bill budget that runs out leaves the rest as remainder', () {
      final (:bills, :remainder) = denominateChange(123456, maxBills: 2);
      expect(bills, [100000, 20000]);
      expect(remainder, 3456);
    });

    test('never needs more bills than the exit budget allows', () {
      // Worst case per decade is three bills (e.g. 9 = 5 + 2 + 2); u32 scaled
      // units span eight full decades above the smallest bill.
      for (final change in [0xFFFFFFFF, 999999999, 99999, 9999999]) {
        final (:bills, :remainder) = denominateChange(change, maxBills: wormholeDefaultExitSlots - 2);
        expect(bills.length, lessThanOrEqualTo(27));
        expect(remainder, lessThan(wormholeMinBillScaled));
      }
    });
  });

  group('selectWormholeInputs', () {
    test('plan worked example: 10 tokens from 1.1 + 5.8 + 4.0', () {
      final plan = selectWormholeInputs(utxos: [utxo(110), utxo(580), utxo(400)], amountToken: tokens('10'));

      expect(plan.inputCount, 3);
      expect(plan.batches.length, 1);
      expect(plan.amountToken, tokens('10'));
      expect(plan.changeToken, tokens('0.89'));
      expect(plan.feeToken, tokens('0.01'));

      final batch = plan.batches.single;
      expect(batch.recipientScaled, 1000);
      // 0.89 is below the smallest bill: one remainder output, no bills.
      expect(batch.billsScaled, isEmpty);
      expect(batch.remainderScaled, 89);
      expect(batch.exitCount, 2);
      expect(batch.exitScaled, wormholeBatchNetScaled(batch.inputs.map((u) => wormholeScaledFromToken(u.amount))));
    });

    test('change is paid out as bills plus a remainder, each its own exit', () {
      // 5000 tokens in, 1234.56 out: net change 3763.93.
      final plan = selectWormholeInputs(utxos: [utxo(500000)], amountToken: tokens('1234.56'));

      final batch = plan.batches.single;
      final net = wormholeNetScaled(500000);
      final change = net - 123456;
      expect(batch.recipientScaled, 123456);
      expect(batch.billsScaled, [200000, 100000, 50000, 20000, 5000, 1000, 200, 100]);
      expect(batch.remainderScaled, change - 376300);
      expect(batch.changeScaled, change);
      expect(batch.changeExitsScaled, [...batch.billsScaled, batch.remainderScaled]);
      expect(batch.exitCount, 1 + 8 + 1);
      expect(plan.changeOutputCount, 9);
      expect(plan.changeToken, wormholeTokenFromScaled(change));
      expect(plan.feeToken, wormholeTokenFromScaled(500000 - net));
    });

    test('a remainder of zero takes no exit', () {
      // Net of 100100 is 100059; sending 990.59 leaves exactly 1000 (10 tokens).
      final plan = selectWormholeInputs(utxos: [utxo(100100)], amountToken: tokens('990.59'));
      final batch = plan.batches.single;
      expect(batch.billsScaled, [1000]);
      expect(batch.remainderScaled, 0);
      expect(batch.changeExitsScaled, [1000]);
      expect(batch.exitCount, 2);
    });

    test('splits across batches beyond 10 inputs, change only in the last', () {
      final plan = selectWormholeInputs(
        utxos: List.generate(12, (i) => utxo(200, id: 'u$i')),
        amountToken: tokens('22'),
      );

      // Ten inputs net 19.99; eleven net 21.98, so the twelfth is required.
      expect(plan.inputCount, 12);
      expect(plan.batches.length, 2);
      expect(plan.batches.every((b) => b.inputs.length <= 10), isTrue);
      expect(plan.batches.first.changeScaled, 0);
      expect(plan.batches.first.recipientScaled, wormholeBatchNetScaled(List.filled(10, 200)));
      expect(plan.batches.last.recipientScaled, 2200 - plan.batches.first.recipientScaled);
      expect(plan.changeToken, tokens('1.98'));
      expect(plan.feeToken, tokens('0.02'));
    });

    test('insufficient funds reports exact max sendable', () {
      final e = throwsA(
        isA<InsufficientEncryptedFunds>().having((e) => e.maxSendableToken, 'maxSendable', tokens('1.99')),
      );
      expect(
        () => selectWormholeInputs(
          utxos: [
            utxo(100),
            utxo(100, id: 'b'),
          ],
          amountToken: tokens('2'),
        ),
        e,
      );
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
      expect(wormholeMaxSendable(List.generate(10, (i) => utxo(50, id: 'u$i'))), tokens('4.99'));
      expect(wormholeMaxSendable(List.generate(11, (i) => utxo(50, id: 'u$i'))), tokens('5.48'));
    });

    test('exactly 10 inputs fit in a single batch', () {
      final plan = selectWormholeInputs(
        utxos: List.generate(10, (i) => utxo(200, id: 'u$i')),
        amountToken: tokens('19'),
      );
      expect(plan.inputCount, 10);
      expect(plan.batches.length, 1);
      expect(plan.batches.single.recipientScaled, 1900);
    });

    test('send max: all input nets consumed with zero change', () {
      final inputs = [utxo(110), utxo(580), utxo(400)];
      final maxSendable = wormholeMaxSendable(inputs);
      final plan = selectWormholeInputs(utxos: inputs, amountToken: maxSendable);
      expect(plan.amountToken, maxSendable);
      expect(plan.changeToken, BigInt.zero);
      expect(plan.changeOutputCount, 0);
      expect(plan.batches.single.exitCount, 1);
    });

    group('bill-aware selection', () {
      // A wallet holding bills from earlier sends.
      final bills = [
        utxo(50000, id: 'a'),
        utxo(20000, id: 'b'),
        utxo(20000, id: 'c'),
        utxo(10000, id: 'd'),
        utxo(5000, id: 'e'),
        utxo(2000, id: 'f'),
        utxo(2000, id: 'g'),
        utxo(1000, id: 'h'),
      ];

      test('prefers the smallest single input that covers the amount over the largest', () {
        final plan = selectWormholeInputs(utxos: bills, amountToken: tokens('95'));
        // 100 tokens nets 99.96: one input, change 4.96 -> 2 + 2 + 0.96.
        // Largest-first would burn the 500 bill and return 200 + 200 + 2 + 2 + 0.80.
        expect(plan.batches.single.inputs.map((u) => u.transfer.id), ['d']);
        expect(plan.changeOutputCount, 3);
        expect(plan.changeToken, tokens('4.96'));
      });

      test('combines bills that land close to the amount', () {
        final plan = selectWormholeInputs(utxos: bills, amountToken: tokens('230'));
        // 200 + 20 + 20 = 240 nets 239.90: change 9.90 -> 5 + 2 + 2 + 0.90.
        expect(plan.batches.single.inputs.map((u) => u.transfer.id), ['b', 'f', 'g']);
        expect(plan.changeOutputCount, 4);
        expect(plan.changeToken, tokens('9.90'));
      });

      test('sweeps a small input along when that leaves fewer change outputs', () {
        final plan = selectWormholeInputs(
          utxos: [
            utxo(100000, id: 'big'),
            utxo(300, id: 'small'),
          ],
          amountToken: tokens('900'),
        );
        // 1000 alone nets 999.60: change 99.60 is six bills and a remainder;
        // 1003 nets 1002.59: change 102.59 is one bill, 2 + 0.59.
        expect(plan.batches.single.inputs.map((u) => u.transfer.id), ['big', 'small']);
        expect(plan.changeOutputCount, 3);
      });

      test('every candidate plan pays the exact amount and respects the fee', () {
        for (final amount in ['1', '7.77', '95', '123.45', '230', '500', '1099.56']) {
          final plan = selectWormholeInputs(utxos: bills, amountToken: tokens(amount));
          final paid = plan.batches.fold<int>(0, (s, b) => s + b.recipientScaled);
          expect(wormholeTokenFromScaled(paid), tokens(amount));
          for (final batch in plan.batches) {
            expect(batch.exitScaled, lessThanOrEqualTo(wormholeNetScaled(inputsScaled(batch))));
            expect(batch.exitCount, lessThanOrEqualTo(wormholeDefaultExitSlots));
          }
          final consumed = plan.batches.fold(BigInt.zero, (s, b) => s + wormholeTokenFromScaled(inputsScaled(b)));
          expect(plan.amountToken + plan.changeToken + plan.feeToken, consumed);
        }
      });
    });

    test('exit slots bound the number of bills', () {
      final plan = selectWormholeInputs(utxos: [utxo(500000)], amountToken: tokens('1234.56'), maxExitSlots: 4);
      final batch = plan.batches.single;
      expect(batch.billsScaled, [200000, 100000]);
      expect(batch.exitCount, 4);
    });
  });
}
