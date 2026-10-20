@Tags(['native'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/src/rust/frb_generated.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

const _mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

WormholeTransfer _transfer({required String toId, required int count}) => WormholeTransfer(
  id: 't$count',
  blockHeight: 1,
  timestamp: DateTime(2026),
  fromId: 'from',
  toId: toId,
  amount: BigInt.from(1000000000000),
  toHash: '0x00',
  leafIndex: BigInt.from(count),
  transferCount: BigInt.from(count),
  extrinsicId: '',
  viaWormhole: false,
);

/// Runs the real [WormholeUtxoService.getUnspentUtxos] over canned transfers:
/// no indexer calls, every nullifier reported unspent unless [spent] says
/// otherwise. The only RPC answered is the genesis hash that names the caches.
class _OfflineUtxoService extends WormholeUtxoService {
  _OfflineUtxoService()
    : super(
        graphQl: GraphQlEndpointService.forUrls([
          'https://indexer.test',
        ], client: MockClient((_) async => throw StateError('offline'))),
        rpc: RpcEndpointService.forUrls(
          ['https://rpc.test'],
          client: MockClient((request) async {
            if (jsonDecode(request.body)['method'] != 'chain_getBlockHash') throw StateError('offline');
            return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x${'ab' * 32}'}), 200);
          }),
        ),
      );

  Map<String, List<WormholeTransfer>> transfersByAddress = {};

  /// Answer for every nullifier the indexer is asked about.
  WormholeSpend? spent;

  /// Nullifier hexes asked about, per call.
  final queried = <List<String>>[];

  @override
  Future<({Map<String, List<WormholeTransfer>> byAddress, int safeCutoff})> getTransfersToMany(
    List<String> addresses, {
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async => (byAddress: {for (final a in addresses) a: transfersByAddress[a] ?? []}, safeCutoff: 1000);

  @override
  Future<Map<String, WormholeSpend>> checkNullifiersSpent(
    List<(String, String)> nullifiers, {
    WormholeProgressCallback? onProgress,
    IsCancelledCallback? isCancelled,
  }) async {
    queried.add([for (final (hex, _) in nullifiers) hex]);
    final s = spent;
    return s == null ? {} : {for (final (hex, _) in nullifiers) hex: s};
  }
}

WormholeSpend _spend({String? blockAuthor}) => WormholeSpend(
  extrinsicId: '0xs',
  blockHeight: 5,
  timestamp: DateTime(2026),
  call: WormholeSpend.privateBatchCall,
  outputs: [WormholeOutput(id: '0000000005-00000-000001', exitAccountId: 'qzAlice', amount: BigInt.zero)],
  blockAuthor: blockAuthor,
);

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
    expect(result.received, hasLength(3));
    expect(result.spends, isEmpty);
  });

  test('a spent nullifier cached without its block author is asked about again until the author is known', () async {
    final pair = HdWalletService().deriveWormholeKeyPair(mnemonic: _mnemonic);
    final owner = WormholeAddressInfo(index: 0, address: pair.address, secretHex: pair.secretHex);
    final service = _OfflineUtxoService()
      ..transfersByAddress = {
        pair.address: [_transfer(toId: pair.address, count: 1)],
      };

    // An indexer that does not report block authors: the spend is cached as is.
    service.spent = _spend();
    final first = await service.getUnspentUtxos(addresses: [owner]);
    expect(first.utxos, isEmpty);
    expect(service.queried, hasLength(1));

    // Asked again on the next scan, and the completed entry replaces it.
    service.spent = _spend(blockAuthor: 'qzMiner');
    final second = await service.getUnspentUtxos(addresses: [owner]);
    expect(service.queried, hasLength(2));
    expect(second.spends.values.single.blockAuthor, 'qzMiner');

    // Now served from the cache.
    await service.getUnspentUtxos(addresses: [owner]);
    expect(service.queried, hasLength(2));
  });
}
