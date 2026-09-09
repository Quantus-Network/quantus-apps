import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

const _hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _prefix = '0123456789abcdef';
const _planck = 'aaaaaaaaaaaaaaaa';
const _mainnet = 'bbbbbbbbbbbbbbbb';
final _v = WormholeUtxoService.cacheVersion;

/// Discovery bound to a chain whose genesis hash starts with [networkId]. The
/// indexer is never consulted here.
WormholeUtxoService _serviceOn(String networkId) => WormholeUtxoService(
  graphQl: GraphQlEndpointService.forUrls([
    'https://indexer.test',
  ], client: MockClient((_) async => throw StateError('indexer must not be queried'))),
  rpc: RpcEndpointService.forUrls(
    ['https://rpc.test'],
    client: MockClient((request) async {
      expect(jsonDecode(request.body)['method'], 'chain_getBlockHash');
      return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'result': '0x${networkId * 4}'}), 200);
    }),
  ),
);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wormhole-cache-');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
  });

  tearDown(() => dir.delete(recursive: true));

  File write(String name, String content) => File('${dir.path}/$name')..writeAsStringSync(content);
  Set<String> names() => dir.listSync().map((e) => e.uri.pathSegments.last).toSet();

  test('Planck-era caches are neither read nor kept after the generation bump', () async {
    // Everything a released wallet may have written before the mainnet switch.
    write('wormhole_nullifiers_v2_$_prefix.json', '["0xspent-on-planck"]');
    write('wormhole_nullifiers_$_prefix.json', '["0xolder"]');
    write('wormhole_cache_v2_$_prefix.json', '{"cachedUpToBlock":123456,"transfers":[]}');
    write('wormhole_cache_$_prefix.json', '{"cachedUpToBlock":1,"transfers":[]}');
    final otherAddress = write('wormhole_nullifiers_v2_ffffffffffffffff.json', '["0x01"]');

    expect(await _serviceOn(_mainnet).loadSpentNullifiers(_hash), isEmpty);
    expect(names(), {otherAddress.uri.pathSegments.last});
  });

  test('current-generation files of every network survive stale cleanup', () async {
    write('wormhole_nullifiers_v${_v}_${_planck}_$_prefix.json', '["0x02"]');
    write('wormhole_cache_v${_v}_${_mainnet}_$_prefix.json', '{"cachedUpToBlock":7,"transfers":[]}');

    await WormholeUtxoService.deleteStaleCaches(_hash);

    expect(names(), {
      'wormhole_nullifiers_v${_v}_${_planck}_$_prefix.json',
      'wormhole_cache_v${_v}_${_mainnet}_$_prefix.json',
    });
    expect(await _serviceOn(_planck).loadSpentNullifiers(_hash), {'0x02'});
  });

  test(
    'switching chains within one generation reads neither the other chain\'s scan height nor its nullifiers',
    () async {
      await _serviceOn(_planck).saveSpentNullifiers(_hash, {'0xspent-on-planck'});
      write('wormhole_cache_v${_v}_${_planck}_$_prefix.json', '{"cachedUpToBlock":123456,"transfers":[]}');

      final mainnet = _serviceOn(_mainnet);
      expect(await mainnet.loadSpentNullifiers(_hash), isEmpty);
      expect(await mainnet.cachedTransferHeight(_hash), 0);

      // Planck's files were namespaced, not cleared: switching back does not rescan.
      final planck = _serviceOn(_planck);
      expect(await planck.loadSpentNullifiers(_hash), {'0xspent-on-planck'});
      expect(await planck.cachedTransferHeight(_hash), 123456);
      expect(names(), {
        'wormhole_nullifiers_v${_v}_${_planck}_$_prefix.json',
        'wormhole_cache_v${_v}_${_planck}_$_prefix.json',
      });
    },
  );

  test('clearCachesForAddresses removes every generation of that address only', () async {
    write('wormhole_cache_$_prefix.json', '{}');
    write('wormhole_cache_v2_$_prefix.json', '{}');
    write('wormhole_nullifiers_v${_v}_${_planck}_$_prefix.json', '[]');
    write('wormhole_nullifiers_v2_ffffffffffffffff.json', '[]');

    await WormholeUtxoService.clearCachesForAddresses([]);
    expect(names(), hasLength(4));
  });
}
