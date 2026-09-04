import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  test('a payload without endpoints keeps the default network', () {
    final config = RemoteConfigModel.fromJson(const {'enableSwap': false});
    expect(config.enableSwap, isFalse);
    expect(config.endpoints, NetworkEndpoints.defaults);
  });

  test('cache json round-trips including endpoints', () {
    final config = RemoteConfigModel.fromJson(const {
      'enableTestButtons': true,
      'endpoints': {
        'rpc': ['https://rpc.example.net'],
        'explorer': 'https://explorer.example.net',
      },
    });
    final again = RemoteConfigModel.fromJson(config.toCacheJson());
    expect(again, config);
    expect(again.endpoints.rpc, ['https://rpc.example.net']);
    expect(again.endpoints.explorer, 'https://explorer.example.net');
    expect(again.endpoints.graphQl, NetworkEndpoints.defaults.graphQl);
  });

  test('equality tracks both flags and endpoints', () {
    expect(RemoteConfigModel.fromJson(const {}), RemoteConfigModel.defaults);
    expect(RemoteConfigModel.fromJson(const {'enableSwap': false}), isNot(RemoteConfigModel.defaults));
    expect(
      RemoteConfigModel.fromJson(const {
        'endpoints': {'explorer': 'https://explorer.example.net'},
      }),
      isNot(RemoteConfigModel.defaults),
    );
  });

  test('a bad endpoints block rejects the whole payload', () {
    expect(
      () => RemoteConfigModel.fromJson(const {
        'enableSwap': false,
        'endpoints': {'rpc': <String>[]},
      }),
      throwsFormatException,
    );
  });
}
