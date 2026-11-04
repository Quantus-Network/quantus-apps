@Tags(['native'])
library;

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

/// Serves canned rows per address, recording each request's addresses and
/// how many requests overlap, and optionally failing one address.
class _Indexer extends WormholeUtxoService {
  _Indexer({required int chainHeight, this.failing})
    : super(
        graphQl: GraphQlEndpointService.forUrls([
          'https://indexer.test',
        ], client: MockClient((_) async => throw StateError('transfers go through queryTransferPages'))),
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

  /// Addresses of each request, in request order.
  final List<List<String>> requests = [];
  int inFlight = 0;
  int maxInFlight = 0;

  List<String> get queried => [for (final r in requests) ...r];

  @override
  Future<List<List<WormholeTransfer>>> queryTransferPages(
    List<TransferPageRequest> batch, {
    int limit = WormholeUtxoService.transferPageSize,
  }) async {
    requests.add([for (final r in batch) r.toAddress]);
    inFlight++;
    maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
    // Yield so other workers can start before this one answers.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    inFlight--;
    if (batch.any((r) => r.toAddress == failing)) throw StateError('indexer down');
    return [
      for (final r in batch)
        (rows[r.toAddress] ?? const [])
            .where((t) => t.blockHeight > r.afterBlock)
            .where((t) => r.after == null || t.blockHeight > r.after!.blockHeight)
            .take(limit)
            .toList(),
    ];
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

  test('addresses are paged a batch per request, requests overlap, and each keeps its own transfers', () async {
    const chainHeight = 10000;
    const batch = WormholeUtxoService.transferFetchBatchSize;
    final count = batch * 2 + 5;
    final addresses = [for (var n = 1; n <= count; n++) _address(n)];
    final indexer = _Indexer(chainHeight: chainHeight);
    for (var n = 1; n <= count; n++) {
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

    expect(indexer.requests.map((r) => r.length), [batch, batch, 5]);
    expect(indexer.maxInFlight, 3);
    expect(indexer.queried, addresses);
    expect(result.safeCutoff, chainHeight - 180);
    for (var n = 1; n <= count; n++) {
      expect(result.byAddress[addresses[n - 1]]!.map((t) => t.id), [
        '${(100 * n).toString().padLeft(10, '0')}-$n',
        '0000009990-${100 + n}',
      ]);
    }
    expect(progress.last, count * 2);
    // Only the reorg-safe transfer of each address is persisted.
    for (final address in addresses) {
      final cached = jsonDecode(await cacheFile(address).readAsString()) as Map<String, dynamic>;
      expect(cached['cachedUpToBlock'], chainHeight - 180);
      expect((cached['transfers'] as List).length, 1);
    }
  });

  test('only the addresses whose page was full are asked for another', () async {
    const pageSize = WormholeUtxoService.transferPageSize;
    final addresses = [for (var n = 1; n <= 3; n++) _address(n)];
    final indexer = _Indexer(chainHeight: 10000);
    indexer.rows[addresses[0]] = [for (var i = 1; i <= pageSize + 2; i++) _transfer(addresses[0], i, i)];
    indexer.rows[addresses[1]] = [_transfer(addresses[1], 5, 1)];
    indexer.rows[addresses[2]] = [for (var i = 1; i <= pageSize; i++) _transfer(addresses[2], i, i)];

    final result = await indexer.getTransfersToMany(addresses);

    expect(indexer.requests, [
      addresses,
      [addresses[0], addresses[2]],
    ]);
    expect(result.byAddress[addresses[0]], hasLength(pageSize + 2));
    expect(result.byAddress[addresses[1]], hasLength(1));
    expect(result.byAddress[addresses[2]], hasLength(pageSize));
  });

  test('a failing request fails the scan and stops handing out new requests', () async {
    const batch = WormholeUtxoService.transferFetchBatchSize;
    final addresses = [
      for (var n = 1; n <= batch * (WormholeUtxoService.transferFetchConcurrency + 2); n++) _address(n),
    ];
    final indexer = _Indexer(chainHeight: 10000, failing: addresses[0]);

    await expectLater(indexer.getTransfersToMany(addresses), throwsA(isA<StateError>()));
    // The first wave was already in flight; nothing beyond it was started.
    expect(indexer.requests.length, lessThanOrEqualTo(WormholeUtxoService.transferFetchConcurrency));
  });

  test('nullifiers are computed once and kept in the transfer cache for the next scan', () async {
    final address = _address(1);
    final hashed = <String>[];
    String nullifierFor(String a, WormholeTransfer t) {
      hashed.add(t.id);
      return '0xn${t.id}';
    }

    final first = _Indexer(chainHeight: 10000);
    first.rows[address] = [_transfer(address, 50, 1), _transfer(address, 9990, 2)];
    final scanned = await first.getTransfersToMany([address], nullifierFor: nullifierFor);
    expect(scanned.nullifiers[address], {'0000000050-1': '0xn0000000050-1', '0000009990-2': '0xn0000009990-2'});
    expect(hashed, ['0000000050-1', '0000009990-2']);
    final cached = jsonDecode(await cacheFile(address).readAsString()) as Map<String, dynamic>;
    expect(cached['nullifiers'], {'0000000050-1': '0xn0000000050-1'}, reason: 'only the reorg-safe transfer is cached');

    // Next scan: the cached transfer's nullifier is not hashed again; the
    // one still above the cutoff is.
    hashed.clear();
    final second = _Indexer(chainHeight: 10000);
    second.rows[address] = first.rows[address]!;
    final rescanned = await second.getTransfersToMany([address], nullifierFor: nullifierFor);
    expect(rescanned.nullifiers[address], scanned.nullifiers[address]);
    expect(hashed, ['0000009990-2']);
  });

  test('a cache written before nullifiers were kept is read, filled in and rewritten once', () async {
    final address = _address(1);
    final warm = _Indexer(chainHeight: 10000);
    warm.rows[address] = [_transfer(address, 50, 1)];
    await warm.getTransfersToMany([address]);
    final file = cacheFile(address);
    final legacy = jsonDecode(await file.readAsString()) as Map<String, dynamic>..remove('nullifiers');
    await file.writeAsString(jsonEncode(legacy));

    var hashes = 0;
    String nullifierFor(String a, WormholeTransfer t) {
      hashes++;
      return '0xn${t.id}';
    }

    final filling = _Indexer(chainHeight: 10000);
    filling.rows[address] = warm.rows[address]!;
    await filling.getTransfersToMany([address], nullifierFor: nullifierFor);
    expect(hashes, 1);
    expect((jsonDecode(await file.readAsString()) as Map)['nullifiers'], {'0000000050-1': '0xn0000000050-1'});

    final written = await file.readAsString();
    final settled = _Indexer(chainHeight: 10000);
    settled.rows[address] = warm.rows[address]!;
    await settled.getTransfersToMany([address], nullifierFor: nullifierFor);
    expect(hashes, 1);
    expect(await file.readAsString(), written, reason: 'nothing new: the file is left alone');
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
