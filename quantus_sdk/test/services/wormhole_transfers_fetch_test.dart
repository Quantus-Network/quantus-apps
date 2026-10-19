@Tags(['native'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/src/rust/api/wormhole.dart' as wormhole_ffi;
import 'package:quantus_sdk/src/rust/frb_generated.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';
import 'package:ss58/ss58.dart';

const _genesis = 'cccccccccccccccc';

String _address(int n) => Address(prefix: 189, pubkey: Uint8List(32)..[31] = n).encode();

String _hashOf(String address) =>
    wormhole_ffi.computeAddressHashHex(rawAddress: Uint8List.fromList(getAccountId32(address)));

WormholeTransfer _transfer(String to, int height, int n) => WormholeTransfer(
  id: '${height.toString().padLeft(10, '0')}-$n',
  blockHeight: height,
  timestamp: DateTime(2026),
  fromId: 'from',
  toId: to,
  amount: BigInt.from(n),
  toHash: '',
  leafIndex: BigInt.from(n),
  transferCount: BigInt.from(n),
  extrinsicId: '',
  viaWormhole: false,
);

/// Serves canned rows per address, recording how many fetches overlap, and
/// optionally failing one address.
class _Indexer extends WormholeUtxoService {
  _Indexer({required int chainHeight, this.failing})
    : super(
        graphQl: GraphQlEndpointService.forUrls([
          'https://indexer.test',
        ], client: MockClient((_) async => throw StateError('transfers go through queryTransfersPage'))),
        rpc: RpcEndpointService.forUrls(
          ['https://rpc.test'],
          client: MockClient((request) async {
            final method = jsonDecode(request.body)['method'];
            final result = switch (method) {
              'chain_getBlockHash' => '0x${_genesis * 4}',
              'chain_getHeader' => {'number': '0x${chainHeight.toRadixString(16)}'},
              _ => throw StateError('unexpected RPC $method'),
            };
            return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': result}), 200);
          }),
        ),
      );

  final Map<String, List<WormholeTransfer>> rows = {};
  final String? failing;
  final List<String> queried = [];
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<List<WormholeTransfer>> queryTransfersPage({
    required String toAddress,
    required int afterBlock,
    WormholeTransferCursor? after,
    int limit = WormholeUtxoService.transferPageSize,
  }) async {
    queried.add(toAddress);
    inFlight++;
    maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
    // Yield so other workers can start before this one answers.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    inFlight--;
    if (toAddress == failing) throw StateError('indexer down');
    return (rows[toAddress] ?? const []).where((t) => t.blockHeight > afterBlock).take(limit).toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RustLib.init();
  });

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wormhole-fetch-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await dir.delete(recursive: true);
  });

  File cacheFile(String address) => File(
    '${dir.path}/wormhole_cache_v${WormholeUtxoService.cacheVersion}_${_genesis}_${_hashOf(address).substring(0, 16)}.json',
  );

  test('addresses are fetched concurrently, bounded, and each keeps its own transfers in order', () async {
    const chainHeight = 10000;
    final addresses = [for (var n = 1; n <= 15; n++) _address(n)];
    final indexer = _Indexer(chainHeight: chainHeight);
    for (var n = 1; n <= 15; n++) {
      indexer.rows[addresses[n - 1]] = [
        _transfer(addresses[n - 1], 100 * n, n),
        _transfer(addresses[n - 1], 9990, 100 + n),
      ];
    }
    final progress = <int>[];

    final result = await indexer.getTransfersToMany(
      addresses,
      onProgress: (phase, done, {total}) => progress.add(done),
    );

    expect(indexer.maxInFlight, greaterThan(1));
    expect(indexer.maxInFlight, lessThanOrEqualTo(WormholeUtxoService.transferFetchConcurrency));
    expect(indexer.queried.toSet(), addresses.toSet());
    expect(result.safeCutoff, chainHeight - 180);
    for (var n = 1; n <= 15; n++) {
      expect(result.byAddress[addresses[n - 1]]!.map((t) => t.id), [
        '${(100 * n).toString().padLeft(10, '0')}-$n',
        '0000009990-${100 + n}',
      ]);
    }
    expect(progress.last, 30);
    // Only the reorg-safe transfer of each address is persisted.
    for (final address in addresses) {
      final cached = jsonDecode(await cacheFile(address).readAsString()) as Map<String, dynamic>;
      expect(cached['cachedUpToBlock'], chainHeight - 180);
      expect((cached['transfers'] as List).length, 1);
    }
  });

  test('a failing address fails the scan and stops handing out new addresses', () async {
    final addresses = [for (var n = 1; n <= 20; n++) _address(n)];
    final indexer = _Indexer(chainHeight: 10000, failing: addresses[0]);

    await expectLater(indexer.getTransfersToMany(addresses), throwsA(isA<StateError>()));
    // The first wave was already in flight; nothing beyond it was started.
    expect(indexer.queried.length, lessThanOrEqualTo(WormholeUtxoService.transferFetchConcurrency));
  });

  test('an idle address is not rewritten until its scan height falls a reorg depth behind', () async {
    final address = _address(1);
    final warm = _Indexer(chainHeight: 10000);
    warm.rows[address] = [_transfer(address, 50, 1)];
    await warm.getTransfersToMany([address]);
    final file = cacheFile(address);
    final written = await file.readAsString();
    expect((jsonDecode(written) as Map)['cachedUpToBlock'], 10000 - 180);

    // 100 blocks later, nothing new: the file is left alone.
    final soon = _Indexer(chainHeight: 10100);
    soon.rows[address] = warm.rows[address]!;
    await soon.getTransfersToMany([address]);
    expect(await file.readAsString(), written);
    expect(soon.queried, [address], reason: 'the address is still queried above its cached height');

    // A new reorg-safe transfer forces the write regardless of the cutoff.
    final receipt = _Indexer(chainHeight: 10100);
    receipt.rows[address] = [...warm.rows[address]!, _transfer(address, 9900, 2)];
    final result = await receipt.getTransfersToMany([address]);
    expect(result.byAddress[address]!.map((t) => t.leafIndex), [BigInt.one, BigInt.two]);
    var cached = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(cached['cachedUpToBlock'], 10100 - 180);
    expect((cached['transfers'] as List).length, 2);

    // A reorg depth later with nothing new, the scan height is advanced.
    final later = _Indexer(chainHeight: 10100 + 180);
    later.rows[address] = receipt.rows[address]!;
    await later.getTransfersToMany([address]);
    cached = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(cached['cachedUpToBlock'], 10100);
  });
}
