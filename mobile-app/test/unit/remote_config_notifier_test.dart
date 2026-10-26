import 'dart:async';

import 'package:flutter/foundation.dart';
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

const _endpoint = 'https://oneclick.test';

void main() {
  test('remote config models compare by their flags', () {
    expect(RemoteConfigModel.fromJson(const {}), RemoteConfigModel.defaults);
    expect(RemoteConfigModel.fromJson(const {}).hashCode, RemoteConfigModel.defaults.hashCode);
    expect(RemoteConfigModel.fromJson(const {'enableSwap': true}), isNot(RemoteConfigModel.defaults));
  });

  test('swap is offered only where the server says NEAR Intents is allowed', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(RemoteConfigModel.defaults.geoNearAllowed, isFalse);
    expect(RemoteConfigModel.defaults.enableSwap, isFalse);
    expect(
      RemoteConfigModel.fromJson(const {'enableSwap': true, 'oneClickEndpoint': _endpoint}).swapAvailable,
      isFalse,
    );
    expect(
      RemoteConfigModel.fromJson(const {
        'enableSwap': true,
        'geoNearAllowed': true,
        'oneClickEndpoint': _endpoint,
      }).swapAvailable,
      isTrue,
    );
    expect(
      RemoteConfigModel.fromJson(const {
        'enableSwap': false,
        'geoNearAllowed': true,
        'oneClickEndpoint': _endpoint,
      }).swapAvailable,
      isFalse,
    );
    expect(RemoteConfigModel.fromJson(const {'enableSwap': true, 'geoNearAllowed': true}).swapAvailable, isFalse);
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

  test('the 1Click endpoint, partner key and fee come from the remote config alone', () {
    final unserved = RemoteConfigModel.fromJson(const {});
    expect(unserved.oneClickEndpoint, isNull);
    expect(unserved.nearPartnerJwt, isNull);
    expect(unserved.swapAppFee, isNull);
    expect(RemoteConfigModel.fromJson(const {'oneClickEndpoint': '', 'swapFeeRecipient': 'liq.test'}), unserved);

    final served = RemoteConfigModel.fromJson(const {
      'oneClickEndpoint': _endpoint,
      'near.partner.jwt': 'partner-jwt',
      'swapFeeBips': 40,
      'swapFeeRecipient': 'liq.test',
    });
    expect(served.oneClickEndpoint, _endpoint);
    expect(served.nearPartnerJwt, 'partner-jwt');
    expect(served.swapAppFee, (recipient: 'liq.test', bips: 40));
    expect(RemoteConfigModel.fromJson(served.toCacheJson()), served);
    expect(served, isNot(unserved));
  });

  test('swap is not offered without a 1Click endpoint, whatever the flags or the build', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final flagsOn = RemoteConfigModel.fromJson(const {
        'enableSwap': true,
        'enableSwapAndroid': true,
        'geoNearAllowed': true,
      });
      expect(flagsOn.swapAvailable, isFalse, reason: '$platform');
      expect(
        RemoteConfigModel.fromJson({...flagsOn.toCacheJson(), 'oneClickEndpoint': _endpoint}).swapAvailable,
        isTrue,
      );
    }
  });

  test('a 1Click config that cannot be acted on is refused', () {
    for (final json in const [
      {'oneClickEndpoint': 'oneclick.test'},
      {'oneClickEndpoint': 'ftp://oneclick.test'},
      {'swapFeeBips': 40},
      {'swapFeeBips': -1, 'swapFeeRecipient': 'liq.near'},
    ]) {
      expect(() => RemoteConfigModel.fromJson(json), throwsFormatException, reason: '$json');
    }
  });

  test('revoking the location verdict keeps the rest of the config', () {
    final cached = RemoteConfigModel.fromJson(const {
      'swapQuantusAssetId': 'nep141:qtc.near',
      'geoNearAllowed': true,
      'oneClickEndpoint': _endpoint,
      'near.partner.jwt': 'partner-jwt',
      'swapFeeBips': 40,
      'swapFeeRecipient': 'liq.test',
    });
    final revoked = cached.copyWith(geoNearAllowed: false);
    expect(revoked.geoNearAllowed, isFalse);
    expect(revoked, cached.copyWith(geoNearAllowed: false));
    expect(revoked.toCacheJson(), {...cached.toCacheJson(), 'geoNearAllowed': false});
  });

  test('Android offers swap on its own flag, on by default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(RemoteConfigModel.defaults.enableSwapAndroid, isTrue);
    expect(
      RemoteConfigModel.fromJson(const {'geoNearAllowed': true, 'oneClickEndpoint': _endpoint}).swapAvailable,
      isTrue,
    );
    expect(
      RemoteConfigModel.fromJson(const {'enableSwapAndroid': true, 'oneClickEndpoint': _endpoint}).swapAvailable,
      isFalse,
    );
    expect(
      RemoteConfigModel.fromJson(const {
        'enableSwap': true,
        'enableSwapAndroid': false,
        'geoNearAllowed': true,
        'oneClickEndpoint': _endpoint,
      }).swapAvailable,
      isFalse,
    );
    final off = RemoteConfigModel.fromJson(const {'enableSwapAndroid': false});
    expect(RemoteConfigModel.fromJson(off.toCacheJson()), off);
    expect(off, isNot(RemoteConfigModel.defaults));
  });

  test('iOS keeps its own swap flag and ignores the Android one', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      RemoteConfigModel.fromJson(const {'geoNearAllowed': true, 'oneClickEndpoint': _endpoint}).swapAvailable,
      isFalse,
    );
    expect(
      RemoteConfigModel.fromJson(const {
        'enableSwap': true,
        'enableSwapAndroid': false,
        'geoNearAllowed': true,
        'oneClickEndpoint': _endpoint,
      }).swapAvailable,
      isTrue,
    );
  });

  test('the NEAR Intents recipient check is on unless the remote config turns it off', () {
    expect(RemoteConfigModel.fromJson(const {}).enableOneClickNearWarning, isTrue);
    final off = RemoteConfigModel.fromJson(const {'enableOneClickNearWarning': false});
    expect(off.enableOneClickNearWarning, isFalse);
    expect(RemoteConfigModel.fromJson(off.toCacheJson()), off);
  });

  Future<int> changesAfterSync(RemoteConfigModel? remote) async {
    final notifier = RemoteConfigNotifier(FakeRemoteConfigService(RemoteConfigModel.defaults, remote: remote));
    var changes = 0;
    notifier.addListener((_) => changes++, fireImmediately: false);
    await Future<void>.delayed(Duration.zero);
    return changes;
  }

  test('a cached location allowance is not trusted until this launch hears from the server', () async {
    final allowed = RemoteConfigModel.fromJson(const {
      'enableSwap': true,
      'geoNearAllowed': true,
      'oneClickEndpoint': _endpoint,
    });
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
    final allowed = RemoteConfigModel.fromJson(const {
      'enableSwap': true,
      'geoNearAllowed': true,
      'enableMultisig': false,
      'oneClickEndpoint': _endpoint,
    });
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
    final allowed = RemoteConfigModel.fromJson(const {
      'enableSwap': true,
      'geoNearAllowed': true,
      'enableMultisig': false,
      'oneClickEndpoint': _endpoint,
    });
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

  test('a refresh overlapping an earlier one discards the earlier answer and asks again', () async {
    final allowed = RemoteConfigModel.fromJson(const {
      'enableSwap': true,
      'geoNearAllowed': true,
      'enableMultisig': false,
      'oneClickEndpoint': _endpoint,
    });
    final service = _SlowRemoteConfigService(allowed);
    final notifier = RemoteConfigNotifier(service);
    unawaited(notifier.syncConfig());
    expect(service.responses, hasLength(1));

    service.responses.single.complete(allowed);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.geoNearAllowed, isFalse);
    expect(service.responses, hasLength(2));

    service.responses.last.complete(allowed.copyWith(geoNearAllowed: false));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.geoNearAllowed, isFalse);
    expect(notifier.state.enableMultisig, isFalse);

    unawaited(notifier.syncConfig());
    expect(service.responses, hasLength(3));
    service.responses.last.complete(allowed);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.swapAvailable, isTrue);
  });

  test('syncConfig and settled complete only once the latest answer is in', () async {
    final allowed = RemoteConfigModel.fromJson(const {
      'enableSwap': true,
      'geoNearAllowed': true,
      'oneClickEndpoint': _endpoint,
    });
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

  test('syncing an unchanged remote config does not notify listeners', () async {
    expect(await changesAfterSync(RemoteConfigModel.fromJson(const {})), 0);
  });

  test('syncing a changed remote config notifies listeners once', () async {
    expect(await changesAfterSync(RemoteConfigModel.fromJson(const {'enableSwap': true})), 1);
  });
}
