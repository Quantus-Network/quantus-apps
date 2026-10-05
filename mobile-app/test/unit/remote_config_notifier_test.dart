import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';

import '../fakes.dart';

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

  test('syncing an unchanged remote config does not notify listeners', () async {
    expect(await changesAfterSync(RemoteConfigModel.fromJson(const {})), 0);
  });

  test('syncing a changed remote config notifies listeners once', () async {
    expect(await changesAfterSync(RemoteConfigModel.fromJson(const {'enableSwap': false})), 1);
  });
}
