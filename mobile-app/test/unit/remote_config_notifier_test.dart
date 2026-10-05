import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';

import '../fakes.dart';

/// Answers each remote read only when the test completes it.
class _SlowRemoteConfigService extends FakeRemoteConfigService {
  _SlowRemoteConfigService(super.config);

  final responses = <Completer<RemoteConfigModel?>>[];

  @override
  Future<RemoteConfigModel?> readRemoteConfig() {
    final response = Completer<RemoteConfigModel?>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  test('remote config models compare by their flags', () {
    expect(RemoteConfigModel.fromJson(const {}), RemoteConfigModel.defaults);
    expect(RemoteConfigModel.fromJson(const {}).hashCode, RemoteConfigModel.defaults.hashCode);
    expect(RemoteConfigModel.fromJson(const {'enableSwap': false}), isNot(RemoteConfigModel.defaults));
  });

  test('swap is offered only where the server says NEAR Intents is allowed', () {
    expect(RemoteConfigModel.defaults.geoNearAllowed, isFalse);
    expect(RemoteConfigModel.fromJson(const {'enableSwap': true}).swapAvailable, isFalse);
    expect(RemoteConfigModel.fromJson(const {'enableSwap': true, 'geoNearAllowed': true}).swapAvailable, isTrue);
    expect(RemoteConfigModel.fromJson(const {'enableSwap': false, 'geoNearAllowed': true}).swapAvailable, isFalse);
    final allowed = RemoteConfigModel.fromJson(const {'geoNearAllowed': true});
    expect(RemoteConfigModel.fromJson(allowed.toCacheJson()), allowed);
    expect(allowed, isNot(RemoteConfigModel.defaults));
  });

  test('the Quantus swap asset id is null unless the remote config names one', () {
    expect(RemoteConfigModel.defaults.swapQuantusAssetId, isNull);
    expect(RemoteConfigModel.fromJson(const {'swapQuantusAssetId': ''}).swapQuantusAssetId, isNull);
    final named = RemoteConfigModel.fromJson(const {'swapQuantusAssetId': 'nep141:qtc.omft.near'});
    expect(named.swapQuantusAssetId, 'nep141:qtc.omft.near');
    expect(RemoteConfigModel.fromJson(named.toCacheJson()), named);
    expect(named, isNot(RemoteConfigModel.defaults));
  });

  Future<int> changesAfterSync(RemoteConfigModel? remote) async {
    final notifier = RemoteConfigNotifier(FakeRemoteConfigService(RemoteConfigModel.defaults, remote: remote));
    var changes = 0;
    notifier.addListener((_) => changes++, fireImmediately: false);
    await Future<void>.delayed(Duration.zero);
    return changes;
  }

  test('a cached location allowance is not trusted until this launch hears from the server', () async {
    final allowed = RemoteConfigModel.fromJson(const {'geoNearAllowed': true});
    final offline = RemoteConfigNotifier(FakeRemoteConfigService(allowed));
    expect(offline.state.geoNearAllowed, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(offline.state.geoNearAllowed, isFalse);
    expect(offline.state.enableSwap, isTrue);

    final online = RemoteConfigNotifier(FakeRemoteConfigService(allowed, remote: allowed));
    expect(online.state.geoNearAllowed, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(online.state.geoNearAllowed, isTrue);
  });

  test('a refresh that fails revokes the location allowance and keeps the other flags', () async {
    final allowed = RemoteConfigModel.fromJson(const {'geoNearAllowed': true, 'enableMultisig': false});
    final service = FakeRemoteConfigService(allowed, remote: allowed);
    final notifier = RemoteConfigNotifier(service);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isTrue);

    service.remote = null;
    await notifier.syncConfig();
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.geoNearAllowed, isFalse);
    expect(notifier.state.enableMultisig, isFalse);
  });

  test('a foreground refresh revokes the allowance while its answer is pending', () async {
    final allowed = RemoteConfigModel.fromJson(const {'geoNearAllowed': true, 'enableMultisig': false});
    final service = _SlowRemoteConfigService(allowed);
    final notifier = RemoteConfigNotifier(service);
    service.responses.single.complete(allowed);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isTrue);

    unawaited(notifier.syncConfig());
    expect(notifier.state.geoNearAllowed, isFalse);
    expect(notifier.state.enableMultisig, isFalse);
    expect(service.responses, hasLength(2));

    service.responses.last.complete(allowed);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isTrue);

    unawaited(notifier.syncConfig());
    service.responses.last.complete(allowed.copyWith(geoNearAllowed: false));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.geoNearAllowed, isFalse);
  });

  test('syncing an unchanged remote config does not notify listeners', () async {
    expect(await changesAfterSync(RemoteConfigModel.fromJson(const {})), 0);
  });

  test('syncing a changed remote config notifies listeners once', () async {
    expect(await changesAfterSync(RemoteConfigModel.fromJson(const {'enableSwap': false})), 1);
  });
}
