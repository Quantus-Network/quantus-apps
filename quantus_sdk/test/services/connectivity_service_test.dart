import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class _FakeConnectivity implements Connectivity {
  final changes = StreamController<List<ConnectivityResult>>.broadcast();
  final calls = <String>[];
  List<ConnectivityResult> answer;

  _FakeConnectivity(this.answer);

  int get checks => calls.where((c) => c == 'check').length;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    calls.add('listen');
    return changes.stream;
  }

  /// Answers on the next frame, as a platform round trip would.
  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    calls.add('check');
    return Future.delayed(Duration.zero, () => answer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeConnectivity platform;
  late ConnectivityService service;
  late List<NetworkStatus> statuses;
  late List<List<ConnectivityResult>> results;

  Future<void> setLifecycle(AppLifecycleState state) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.lifecycle.name,
        const StringCodec().encodeMessage(state.toString()),
        (_) {},
      );

  Future<void> start(WidgetTester tester, List<ConnectivityResult> answer, {bool listen = true}) async {
    await setLifecycle(AppLifecycleState.resumed);
    platform = _FakeConnectivity(answer);
    service = ConnectivityService(connectivity: platform);
    addTearDown(() => setLifecycle(AppLifecycleState.resumed));
    statuses = [];
    results = [];
    if (listen) {
      service.statusStream.listen(statuses.add);
      service.resultsStream.listen(results.add);
    }
    await tester.pump(Duration.zero);
  }

  testWidgets('listens before the first check and seeds the status from the answer', (tester) async {
    await start(tester, const [ConnectivityResult.none]);

    expect(platform.calls, ['listen', 'check']);
    expect(service.currentStatus, NetworkStatus.offline);
    expect(service.currentResults, const [ConnectivityResult.none]);
    expect(statuses, [NetworkStatus.online, NetworkStatus.offline]);
    expect(results, const [
      [],
      [ConnectivityResult.none],
    ]);
    service.dispose();
  });

  testWidgets('streams every platform change and only distinct values', (tester) async {
    await start(tester, const [ConnectivityResult.wifi]);

    platform.changes.add(const [ConnectivityResult.wifi, ConnectivityResult.vpn]);
    platform.changes.add(const [ConnectivityResult.wifi, ConnectivityResult.vpn]);
    platform.changes.add(const [ConnectivityResult.none]);
    await tester.pump(Duration.zero);

    expect(service.currentStatus, NetworkStatus.offline);
    expect(statuses, [NetworkStatus.online, NetworkStatus.offline]);
    expect(results, const [
      [],
      [ConnectivityResult.wifi],
      [ConnectivityResult.wifi, ConnectivityResult.vpn],
      [ConnectivityResult.none],
    ]);
    service.dispose();
  });

  testWidgets('a stale stream value is corrected by the timed re-read', (tester) async {
    await start(tester, const [ConnectivityResult.none]);

    platform.changes.add(const [ConnectivityResult.mobile]);
    await tester.pump(Duration.zero);
    expect(service.currentStatus, NetworkStatus.online);

    await tester.pump(ConnectivityService.defaultVerifyInterval);
    expect(service.currentStatus, NetworkStatus.offline);
    expect(platform.checks, 2);
    service.dispose();
  });

  testWidgets('re-reads only while a stream has a listener', (tester) async {
    await start(tester, const [ConnectivityResult.wifi], listen: false);

    await tester.pump(ConnectivityService.defaultVerifyInterval * 2);
    expect(platform.checks, 1);

    final subscription = service.statusStream.listen((_) {});
    await tester.pump(ConnectivityService.defaultVerifyInterval);
    expect(platform.checks, 2);

    // Awaiting the cancel of an async* subscription never completes under the
    // test binding's fake async; the timer is cancelled synchronously anyway.
    unawaited(subscription.cancel());
    await tester.pump(ConnectivityService.defaultVerifyInterval * 2);
    expect(platform.checks, 2);
    service.dispose();
  });

  testWidgets('stops re-reading in the background and re-reads at once on resume', (tester) async {
    await start(tester, const [ConnectivityResult.wifi]);

    await setLifecycle(AppLifecycleState.inactive);
    await setLifecycle(AppLifecycleState.paused);
    await tester.pump(ConnectivityService.defaultVerifyInterval * 3);
    expect(platform.checks, 1);

    platform.answer = const [ConnectivityResult.none];
    await setLifecycle(AppLifecycleState.resumed);
    await tester.pump(Duration.zero);
    expect(platform.checks, 2);
    expect(service.currentStatus, NetworkStatus.offline);

    await tester.pump(ConnectivityService.defaultVerifyInterval);
    expect(platform.checks, 3);
    service.dispose();
  });

  testWidgets('replays the current state to a late subscriber', (tester) async {
    await start(tester, const [ConnectivityResult.none], listen: false);

    expect(await service.statusStream.first, NetworkStatus.offline);
    expect(await service.resultsStream.first, const [ConnectivityResult.none]);
    service.dispose();
  });
}
