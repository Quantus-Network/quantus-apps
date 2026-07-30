@Tags(['native'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/rust/frb_generated.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

WormholeTransfer _transfer({required String toId, required int count}) => WormholeTransfer(
  id: 't$count',
  blockHeight: 1,
  fromId: 'from',
  toId: toId,
  amount: BigInt.from(1000000000000),
  toHash: '0x00',
  leafIndex: BigInt.from(count),
  transferCount: BigInt.from(count),
);

/// Runs the real [WormholeUtxoService.getUnspentUtxos] over canned transfers:
/// no indexer or RPC calls, every nullifier reported unspent.
class _OfflineUtxoService extends WormholeUtxoService {
  Map<String, List<WormholeTransfer>> transfersByAddress = {};

  @override
  Future<({Map<String, List<WormholeTransfer>> byAddress, int safeCutoff})> getTransfersToMany(
    List<String> addresses, {
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async => (byAddress: {for (final a in addresses) a: transfersByAddress[a] ?? []}, safeCutoff: 1000);

  @override
  Future<Map<String, int>> checkNullifiersSpent(
    List<(String, String)> nullifiers, {
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wormhole_utxo_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await tempDir.delete(recursive: true);
  });

  test('getUnspentUtxos blanks owner secretHex on every returned UTXO (M11)', () async {
    final hd = HdWalletService();
    final pairs = [for (var i = 0; i < 2; i++) hd.deriveWormholeKeyPair(mnemonic: _mnemonic, index: i)];
    final changePair = hd.deriveWormholeChangeAddressKeyPair(mnemonic: _mnemonic);
    final service = _OfflineUtxoService()
      ..transfersByAddress = {
        pairs[0].address: [_transfer(toId: pairs[0].address, count: 1)],
        pairs[1].address: [_transfer(toId: pairs[1].address, count: 2)],
        changePair.address: [_transfer(toId: changePair.address, count: 3)],
      };

    final result = await service.getUnspentUtxos(
      addresses: [
        for (var i = 0; i < 2; i++)
          WormholeAddressInfo(index: i, address: pairs[i].address, secretHex: pairs[i].secretHex),
        WormholeAddressInfo(index: 0, isChange: true, address: changePair.address, secretHex: changePair.secretHex),
      ],
    );

    expect(result.utxos, hasLength(3));
    for (final utxo in result.utxos) {
      expect(utxo.owner.secretHex, isEmpty);
    }
    // Index, branch and address survive the redaction so spenders can re-derive.
    expect(result.utxos.map((u) => u.owner.address).toSet(), {pairs[0].address, pairs[1].address, changePair.address});
    final changeUtxo = result.utxos.singleWhere((u) => u.owner.address == changePair.address);
    expect(changeUtxo.owner.isChange, isTrue);
    expect(changeUtxo.owner.index, 0);
    // Change-branch receipts are totalled separately from external receipts.
    expect(result.changeReceivedPlanck, changeUtxo.amount);
    expect(result.totalReceivedPlanck, result.utxos.fold(BigInt.zero, (sum, u) => sum + u.amount));
  });
}
