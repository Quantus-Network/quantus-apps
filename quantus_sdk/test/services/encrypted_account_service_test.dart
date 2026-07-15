import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/services/encrypted_account_service.dart';
import 'package:quantus_sdk/src/services/wormhole_coin_selection.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

WormholeUtxo _utxo(int scaled, {int index = 0}) => WormholeUtxo(
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
  owner: WormholeAddressInfo(index: index, address: 'addr_$index', secretHex: '0x00'),
  nullifierHex: '0xn$scaled',
);

void main() {
  group('PendingSpend', () {
    test('round-trips through JSON', () {
      final original = PendingSpend(
        nullifiers: ['0xabc', '0xdef'],
        changeAddress: 'addr_3',
        changeAmountPlanck: BigInt.from(123456),
        createdAtMs: 1700000000000,
      );
      final json = original.toJson();
      final restored = PendingSpend.fromJson(json);

      expect(restored.nullifiers, original.nullifiers);
      expect(restored.changeAddress, original.changeAddress);
      expect(restored.changeAmountPlanck, original.changeAmountPlanck);
      expect(restored.createdAtMs, original.createdAtMs);
    });

    test('round-trips with null changeAddress', () {
      final original = PendingSpend(
        nullifiers: ['0x01'],
        changeAddress: null,
        changeAmountPlanck: BigInt.zero,
        createdAtMs: 1700000000000,
      );
      final json = original.toJson();
      final restored = PendingSpend.fromJson(json);

      expect(restored.changeAddress, isNull);
      expect(restored.changeAmountPlanck, BigInt.zero);
    });
  });

  group('EncryptedAccountState', () {
    test('balance includes pending change', () {
      final state = EncryptedAccountState(
        utxos: [_utxo(100), _utxo(200)],
        pendingChangePlanck: wormholePlanckFromScaled(50),
        totalReceivedPlanck: wormholePlanckFromScaled(500),
        totalSpentPlanck: wormholePlanckFromScaled(150),
        nextIndex: 2,
      );
      final utxoSum = wormholePlanckFromScaled(100) + wormholePlanckFromScaled(200);
      expect(state.balance, utxoSum + wormholePlanckFromScaled(50));
    });

    test('maxSendable excludes pending change', () {
      final utxos = [_utxo(100), _utxo(200)];
      final state = EncryptedAccountState(
        utxos: utxos,
        pendingChangePlanck: wormholePlanckFromScaled(50),
        totalReceivedPlanck: wormholePlanckFromScaled(500),
        totalSpentPlanck: wormholePlanckFromScaled(150),
        nextIndex: 2,
      );
      expect(state.maxSendable, wormholeMaxSendable(utxos));
    });

    test('totalReceivedPlanck and totalSpentPlanck are stored', () {
      final received = wormholePlanckFromScaled(1000);
      final spent = wormholePlanckFromScaled(300);
      final state = EncryptedAccountState(
        utxos: [],
        pendingChangePlanck: BigInt.zero,
        totalReceivedPlanck: received,
        totalSpentPlanck: spent,
        nextIndex: 5,
      );
      expect(state.totalReceivedPlanck, received);
      expect(state.totalSpentPlanck, spent);
    });
  });

  group('WormholeUtxoResult', () {
    test('carries totals alongside utxos', () {
      final utxos = [_utxo(100), _utxo(200)];
      final result = WormholeUtxoResult(
        utxos: utxos,
        totalReceivedPlanck: wormholePlanckFromScaled(500),
        totalSpentPlanck: wormholePlanckFromScaled(200),
      );
      expect(result.utxos.length, 2);
      expect(result.totalReceivedPlanck, wormholePlanckFromScaled(500));
      expect(result.totalSpentPlanck, wormholePlanckFromScaled(200));
    });
  });
}
