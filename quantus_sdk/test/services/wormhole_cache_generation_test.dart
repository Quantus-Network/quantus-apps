import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quantus_sdk/src/services/wormhole_utxo_service.dart';

class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

const _hash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _prefix = '0123456789abcdef';

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

    expect(await WormholeUtxoService.loadSpentNullifiers(_hash), isEmpty);
    expect(names(), {otherAddress.uri.pathSegments.last});
  });

  test('current-generation files survive stale cleanup', () async {
    final v = WormholeUtxoService.cacheVersion;
    write('wormhole_nullifiers_v${v}_$_prefix.json', '["0x02"]');
    write('wormhole_cache_v${v}_$_prefix.json', '{"cachedUpToBlock":7,"transfers":[]}');

    await WormholeUtxoService.deleteStaleCaches(_hash);

    expect(names(), {'wormhole_nullifiers_v${v}_$_prefix.json', 'wormhole_cache_v${v}_$_prefix.json'});
    expect(await WormholeUtxoService.loadSpentNullifiers(_hash), {'0x02'});
  });

  test('clearCachesForAddresses removes every generation of that address only', () async {
    write('wormhole_cache_$_prefix.json', '{}');
    write('wormhole_cache_v2_$_prefix.json', '{}');
    write('wormhole_nullifiers_v${WormholeUtxoService.cacheVersion}_$_prefix.json', '[]');
    write('wormhole_nullifiers_v2_ffffffffffffffff.json', '[]');

    await WormholeUtxoService.clearCachesForAddresses([]);
    expect(names(), hasLength(4));
  });
}
