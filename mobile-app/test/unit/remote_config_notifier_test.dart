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
  final denied = RemoteConfigModel.fromJson(const {'geoNearAllowed': false});

  test('remote config models compare by their flags', () {
    expect(RemoteConfigModel.fromJson(const {}), RemoteConfigModel.defaults);
    expect(RemoteConfigModel.fromJson(const {}).hashCode, RemoteConfigModel.defaults.hashCode);
    expect(denied, isNot(RemoteConfigModel.defaults));
  });

  test('swap is offered unless the server says NEAR Intents is not allowed here', () {
    expect(RemoteConfigModel.defaults.geoNearAllowed, isTrue);
    expect(RemoteConfigModel.defaults.swapAvailable, isTrue);
    expect(denied.swapAvailable, isFalse);
    expect(RemoteConfigModel.fromJson(denied.toCacheJson()), denied);
  });

  test('the Quantus swap asset id is null unless the remote config names one', () {
    expect(RemoteConfigModel.defaults.swapQuantusAssetId, isNull);
    expect(RemoteConfigModel.fromJson(const {'swapQuantusAssetId': ''}).swapQuantusAssetId, isNull);
    final named = RemoteConfigModel.fromJson(const {'swapQuantusAssetId': 'nep141:qtc.omft.near'});
    expect(named.swapQuantusAssetId, 'nep141:qtc.omft.near');
    expect(RemoteConfigModel.fromJson(named.toCacheJson()), named);
    expect(named, isNot(RemoteConfigModel.defaults));
  });

  test('the NEAR Intents recipient check is on unless the remote config turns it off', () {
    expect(RemoteConfigModel.fromJson(const {}).enableOneClickNearWarning, isTrue);
    final off = RemoteConfigModel.fromJson(const {'enableOneClickNearWarning': false});
    expect(off.enableOneClickNearWarning, isFalse);
    expect(RemoteConfigModel.fromJson(off.toCacheJson()), off);
  });

  test('the cached location verdict holds until the server answers', () async {
    final offline = RemoteConfigNotifier(FakeRemoteConfigService(denied));
    expect(offline.state.swapAvailable, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(offline.state.swapAvailable, isFalse);

    final online = RemoteConfigNotifier(FakeRemoteConfigService(denied, remote: RemoteConfigModel.defaults));
    expect(online.state.swapAvailable, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(online.state.swapAvailable, isTrue);
  });

  test('a refresh that fails keeps the cached flags', () async {
    final cached = RemoteConfigModel.fromJson(const {'geoNearAllowed': false, 'enableMultisig': false});
    final notifier = RemoteConfigNotifier(FakeRemoteConfigService(cached));
    await notifier.syncConfig();
    expect(notifier.state, cached);
  });

  test('a refresh keeps the verdict while its answer is pending, then takes the answer', () async {
    final service = _SlowRemoteConfigService(RemoteConfigModel.defaults);
    final notifier = RemoteConfigNotifier(service);
    service.responses.single.complete(RemoteConfigModel.defaults);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isTrue);

    unawaited(notifier.syncConfig());
    expect(notifier.state.swapAvailable, isTrue);
    expect(service.responses, hasLength(2));
    service.responses.last.complete(denied);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isFalse);

    unawaited(notifier.syncConfig());
    service.responses.last.complete(RemoteConfigModel.defaults);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isTrue);
  });

  test('a refresh overlapping an earlier one discards the earlier answer and asks again', () async {
    final service = _SlowRemoteConfigService(RemoteConfigModel.defaults);
    final notifier = RemoteConfigNotifier(service);
    unawaited(notifier.syncConfig());
    expect(service.responses, hasLength(1));

    service.responses.single.complete(denied);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isTrue);
    expect(service.responses, hasLength(2));

    service.responses.last.complete(denied);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isFalse);

    unawaited(notifier.syncConfig());
    expect(service.responses, hasLength(3));
    service.responses.last.complete(RemoteConfigModel.defaults);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isTrue);
  });

  test('syncConfig and settled complete only once the latest answer is in', () async {
    const allowed = RemoteConfigModel.defaults;
    final service = _SlowRemoteConfigService(allowed);
    final notifier = RemoteConfigNotifier(service);
    var synced = false;
    var settled = false;
    unawaited(notifier.syncConfig().then((_) => synced = true));
    unawaited(notifier.settled.then((_) => settled = true));
    await Future<void>.delayed(Duration.zero);
    expect(synced, isFalse);
    expect(settled, isFalse);

    service.responses.first.complete(allowed);
    await Future<void>.delayed(Duration.zero);
    expect(synced, isFalse);
    expect(service.responses, hasLength(2));

    service.responses.last.complete(allowed);
    await Future<void>.delayed(Duration.zero);
    expect(synced, isTrue);
    expect(settled, isTrue);
    expect(notifier.state.swapAvailable, isTrue);
    var idle = false;
    unawaited(notifier.settled.then((_) => idle = true));
    await Future<void>.delayed(Duration.zero);
    expect(idle, isTrue);
  });

  Future<int> changesAfterSync(RemoteConfigModel? remote) async {
    final notifier = RemoteConfigNotifier(FakeRemoteConfigService(RemoteConfigModel.defaults, remote: remote));
    var changes = 0;
    notifier.addListener((_) => changes++, fireImmediately: false);
    await Future<void>.delayed(Duration.zero);
    return changes;
  }

  test('syncing an unchanged remote config does not notify listeners', () async {
    expect(await changesAfterSync(RemoteConfigModel.fromJson(const {})), 0);
  });

  test('syncing a changed remote config notifies listeners once', () async {
    expect(await changesAfterSync(denied), 1);
  });
}
