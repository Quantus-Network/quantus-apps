import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/src/services/account_discovery_service.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';

String _address(int index) => 'addr-$index';

/// An indexer that knows exactly the accounts in [onChain].
AccountDiscoveryService _discoveryAgainst(Set<String> onChain) => AccountDiscoveryService(
  HdWalletService(),
  graphQl: GraphQlEndpointService.forUrls(
    ['https://indexer.test'],
    client: MockClient((request) async {
      final ids = (jsonDecode(request.body)['variables']['ids'] as List).cast<String>();
      return http.Response(
        jsonEncode({
          'data': {
            'accounts': [
              for (final id in ids)
                if (onChain.contains(id)) {'id': id},
            ],
          },
        }),
        200,
      );
    }),
  ),
);

void main() {
  test('the batched scan keeps walking past gaps until gapLimit consecutive indices are unused', () async {
    // A wallet restored on a new device: used indices spread over two probe
    // windows with gaps of 14 and 18 between them, each under the gap limit.
    final discovery = _discoveryAgainst({_address(0), _address(15), _address(34)});
    final batches = <List<int>>[];

    final used = await discovery.discoverUsedIndicesBatched(
      addressesAt: (indices) async {
        batches.add(indices);
        return indices.map(_address).toList();
      },
    );

    expect(used, {0, 15, 34});
    // 0..19 (0 and 15 used), 20..39 (34 used; 5 misses after it), 40..59 (closes the gap).
    expect(batches, [
      [for (var i = 0; i < 20; i++) i],
      [for (var i = 20; i < 40; i++) i],
      [for (var i = 40; i < 60; i++) i],
    ]);
  });

  test('an unused sequence stops after a single probe', () async {
    final discovery = _discoveryAgainst(const {});
    var probes = 0;
    final used = await discovery.discoverUsedIndicesBatched(
      addressesAt: (indices) async {
        probes++;
        return indices.map(_address).toList();
      },
    );
    expect(used, isEmpty);
    expect(probes, 1);
  });

  test('the per-index entry point is the batched scan over a sync deriver', () async {
    final discovery = _discoveryAgainst({_address(3)});
    final used = await discovery.discoverUsedIndices(addressAt: _address);
    expect(used, {3});
  });

  test('a deriver returning the wrong number of addresses is rejected', () async {
    final discovery = _discoveryAgainst(const {});
    await expectLater(
      discovery.discoverUsedIndicesBatched(addressesAt: (indices) async => [_address(0)]),
      throwsA(isA<StateError>()),
    );
  });
}
