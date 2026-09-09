import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  tearDown(() => NetworkEndpointsService().apply(NetworkEndpoints.defaults));

  test('setEndpoints replaces the set but keeps latency of endpoints that stay', () {
    final rpc = RpcEndpointService();
    final kept = rpc.endpoints.first;
    kept.latency = const Duration(milliseconds: 5);

    rpc.setEndpoints(['https://rpc.example.net', kept.url]);

    expect(rpc.endpoints.map((e) => e.url), [kept.url, 'https://rpc.example.net']);
    expect(rpc.endpoints.first, same(kept));
    expect(rpc.endpoints.last.latency, isNull);
  });

  test('apply pushes endpoints into the rpc and graphql services', () {
    final endpoints = NetworkEndpoints.fromJson(const {
      'rpc': ['https://rpc.example.net'],
      'graphQl': ['https://indexer.example.net/v1/graphql'],
      'explorer': 'https://explorer.example.net',
      'senoti': 'https://snt.example.net/api',
    });

    NetworkEndpointsService().apply(endpoints);

    expect(NetworkEndpointsService().current, endpoints);
    expect(RpcEndpointService().bestEndpointUrl, 'https://rpc.example.net');
    expect(GraphQlEndpointService().endpoints.map((e) => e.url), ['https://indexer.example.net/v1/graphql']);

    NetworkEndpointsService().apply(NetworkEndpoints.defaults);

    expect(RpcEndpointService().endpoints.map((e) => e.url), unorderedEquals(AppConstants.rpcEndpoints));
    expect(GraphQlEndpointService().endpoints.map((e) => e.url), AppConstants.graphQlEndpoints);
  });
}
