import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  const overrides = {
    'rpc': ['wss://rpc-1.example.net', 'https://rpc-2.example.net/'],
    'graphQl': ['https://indexer.example.net/v1/graphql'],
    'explorer': 'https://explorer.example.net/',
    'senoti': 'https://snt.example.net/api',
  };

  test('absent keys keep the built-in defaults', () {
    expect(NetworkEndpoints.fromJson(const {}), NetworkEndpoints.defaults);
    expect(NetworkEndpoints.defaults.rpc, AppConstants.rpcEndpoints);
    expect(NetworkEndpoints.defaults.graphQl, AppConstants.graphQlEndpoints);
    expect(NetworkEndpoints.defaults.explorer, AppConstants.explorerEndpoint);
    expect(NetworkEndpoints.defaults.senoti, AppConstants.senotiEndpoint);
  });

  test('present keys override and lose trailing slashes', () {
    final endpoints = NetworkEndpoints.fromJson(overrides);
    expect(endpoints.rpc, ['wss://rpc-1.example.net', 'https://rpc-2.example.net']);
    expect(endpoints.graphQl, ['https://indexer.example.net/v1/graphql']);
    expect(endpoints.explorer, 'https://explorer.example.net');
    expect(endpoints.senoti, 'https://snt.example.net/api');
    expect(endpoints, isNot(NetworkEndpoints.defaults));
  });

  test('partial override keeps defaults for the rest', () {
    final endpoints = NetworkEndpoints.fromJson(const {
      'rpc': ['https://rpc.example.net'],
    });
    expect(endpoints.rpc, ['https://rpc.example.net']);
    expect(endpoints.graphQl, NetworkEndpoints.defaults.graphQl);
    expect(endpoints.explorer, NetworkEndpoints.defaults.explorer);
  });

  test('toJson round-trips with value equality', () {
    final endpoints = NetworkEndpoints.fromJson(overrides);
    final again = NetworkEndpoints.fromJson(endpoints.toJson());
    expect(again, endpoints);
    expect(again.hashCode, endpoints.hashCode);
  });

  test('malformed values reject the whole block', () {
    final bad = <Map<String, dynamic>>[
      {'rpc': <String>[]},
      {'rpc': 'https://rpc.example.net'},
      {
        'rpc': ['ftp://rpc.example.net'],
      },
      {
        'rpc': ['not a url'],
      },
      {
        'graphQl': ['wss://indexer.example.net'],
      },
      {'explorer': 'explorer.example.net'},
      {'senoti': 42},
      {'senoti': 'https://'},
    ];
    for (final json in bad) {
      expect(() => NetworkEndpoints.fromJson(json), throwsFormatException, reason: '$json');
    }
  });
}
