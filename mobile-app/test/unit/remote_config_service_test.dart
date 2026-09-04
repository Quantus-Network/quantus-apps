import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/remote_config_service.dart';

import '../fakes.dart';

class FakeQuersiService extends Fake implements QuersiService {
  final Future<RemoteConfigModel> Function() answer;
  FakeQuersiService(this.answer);

  @override
  Future<RemoteConfigModel> getRemoteConfig() => answer();
}

void main() {
  final overrides = RemoteConfigModel.fromJson(const {
    'enableSwap': false,
    'endpoints': {
      'rpc': ['https://rpc.example.net'],
      'explorer': 'https://explorer.example.net',
    },
  });

  RemoteConfigService service(Future<RemoteConfigModel> Function() answer) =>
      RemoteConfigService(quersiService: FakeQuersiService(answer), settingsService: FakeSettingsService());

  tearDown(() => NetworkEndpointsService().apply(NetworkEndpoints.defaults));

  test('an unreachable quersi server yields no remote config instead of an error', () async {
    final failures = <Object>[
      const SocketException('Failed host lookup: qrc-1.quantus.com'),
      TimeoutException('quersi', const Duration(seconds: 10)),
      Exception('Configs request failed with status: 503'),
      const FormatException('Remote config endpoints.rpc must be a non-empty list of URLs: []'),
    ];
    for (final failure in failures) {
      expect(await service(() => Future.error(failure)).readRemoteConfig(), isNull, reason: '$failure');
    }
  });

  test('the wallet keeps the in-code defaults when quersi is unreachable', () async {
    final notifier = RemoteConfigNotifier(service(() => Future.error(const SocketException('unreachable'))));
    await pumpEventQueue();

    expect(notifier.state, RemoteConfigModel.defaults);
    expect(NetworkEndpointsService().current, NetworkEndpoints.defaults);
    expect(AppConstants.rpcEndpoints, contains(RpcEndpointService().bestEndpointUrl));
  });

  test('a reachable quersi server applies its flags and endpoints', () async {
    final notifier = RemoteConfigNotifier(service(() async => overrides));
    await pumpEventQueue();

    expect(notifier.state, overrides);
    expect(NetworkEndpointsService().current, overrides.endpoints);
    expect(RpcEndpointService().bestEndpointUrl, 'https://rpc.example.net');
  });
}
