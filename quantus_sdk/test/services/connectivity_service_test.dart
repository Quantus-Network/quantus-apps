import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class _FakeConnectivity implements Connectivity {
  final changes = StreamController<List<ConnectivityResult>>.broadcast();
  final calls = <String>[];
  List<ConnectivityResult> answer;
  Completer<List<ConnectivityResult>>? held;
  Object? error;

  _FakeConnectivity(this.answer);

  int get checks => calls.where((c) => c == 'check').length;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    calls.add('listen');
    return changes.stream;
  }

  /// Answers on the next frame, as a platform round trip would, unless a test
  /// holds the reply with [held] or fails it with [error].
  @override
  Future<List<ConnectivityResult>> checkConnectivity() {
    calls.add('check');
    final held = this.held;
    if (held != null) return held.future;
    final error = this.error;
    if (error != null) return Future.delayed(Duration.zero, () => throw error);
    return Future.delayed(Duration.zero, () => answer);
  }
}

void main() {
  const interval = ConnectivityService.defaultRetryInterval;

  late _FakeConnectivity platform;
  late ConnectivityService service;
  late List<NetworkStatus> statuses;
  late List<List<ConnectivityResult>> results;

  Future<void> start(
    WidgetTester tester,
    List<ConnectivityResult> answer, {
    bool listen = true,
    bool hold = false,
    bool settle = true,
  }) async {
    platform = _FakeConnectivity(answer);
    if (hold) platform.held = Completer<List<ConnectivityResult>>();
    service = ConnectivityService(connectivity: platform);
    statuses = [];
    results = [];
    if (listen) {
      service.statusStream.listen(statuses.add);
      service.resultsStream.listen(results.add);
    }
    if (settle) await tester.pump(Duration.zero);
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

  testWidgets('never re-reads while online', (tester) async {
    await start(tester, const [ConnectivityResult.wifi]);

    await tester.pump(interval * 5);
    expect(platform.checks, 1);
    expect(statuses, [NetworkStatus.online]);
    service.dispose();
  });

  testWidgets('re-reads every interval while offline until the platform answers online', (tester) async {
    await start(tester, const [ConnectivityResult.none]);

    await tester.pump(interval);
    await tester.pump(interval);
    expect(platform.checks, 3);
    expect(service.currentStatus, NetworkStatus.offline);

    platform.answer = const [ConnectivityResult.wifi];
    await tester.pump(interval);
    expect(platform.checks, 4);
    expect(service.currentStatus, NetworkStatus.online);

    await tester.pump(interval * 5);
    expect(platform.checks, 4);
    expect(statuses, [NetworkStatus.online, NetworkStatus.offline, NetworkStatus.online]);
    service.dispose();
  });

  testWidgets('a stream loss starts re-reading and a stream recovery stops it', (tester) async {
    await start(tester, const [ConnectivityResult.wifi]);

    platform.changes.add(const [ConnectivityResult.none]);
    await tester.pump(Duration.zero);
    expect(service.currentStatus, NetworkStatus.offline);
    platform.answer = const [ConnectivityResult.none];
    await tester.pump(interval);
    expect(platform.checks, 2);

    platform.changes.add(const [ConnectivityResult.mobile]);
    await tester.pump(Duration.zero);
    expect(service.currentStatus, NetworkStatus.online);
    await tester.pump(interval * 5);
    expect(platform.checks, 2);
    service.dispose();
  });

  testWidgets('discards a check reply superseded by a stream event', (tester) async {
    await start(tester, const [ConnectivityResult.none]);

    platform.held = Completer<List<ConnectivityResult>>();
    await tester.pump(interval);
    expect(platform.checks, 2);

    platform.changes.add(const [ConnectivityResult.wifi]);
    await tester.pump(Duration.zero);
    expect(service.currentStatus, NetworkStatus.online);

    platform.held!.complete(const [ConnectivityResult.none]);
    await tester.pump(Duration.zero);
    expect(service.currentStatus, NetworkStatus.online);
    expect(statuses, [NetworkStatus.online, NetworkStatus.offline, NetworkStatus.online]);

    await tester.pump(interval * 5);
    expect(platform.checks, 2);
    service.dispose();
  });

  testWidgets('discards a stale online reply and keeps re-reading', (tester) async {
    await start(tester, const [ConnectivityResult.wifi], hold: true);

    platform.changes.add(const [ConnectivityResult.none]);
    await tester.pump(Duration.zero);
    expect(service.currentStatus, NetworkStatus.offline);

    platform.held!.complete(const [ConnectivityResult.wifi]);
    platform.held = null;
    platform.answer = const [ConnectivityResult.none];
    await tester.pump(Duration.zero);
    expect(service.currentStatus, NetworkStatus.offline);

    await tester.pump(interval);
    expect(platform.checks, 2);

    platform.answer = const [ConnectivityResult.wifi];
    await tester.pump(interval);
    expect(service.currentStatus, NetworkStatus.online);
    service.dispose();
  });

  testWidgets('delivers a change that lands while a subscriber attaches', (tester) async {
    await start(tester, const [ConnectivityResult.none], hold: true, settle: false);

    platform.held!.complete(const [ConnectivityResult.none]);
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);

    expect(service.currentStatus, NetworkStatus.offline);
    expect(statuses, [NetworkStatus.online, NetworkStatus.offline]);
    expect(results, const [
      [],
      [ConnectivityResult.none],
    ]);
    service.dispose();
  });

  testWidgets('keeps re-reading after a failed check and recovers on the next read', (tester) async {
    await start(tester, const [ConnectivityResult.none]);

    platform.error = StateError('platform read failed');
    await tester.pump(interval);
    expect(platform.checks, 2);
    expect(service.currentStatus, NetworkStatus.offline);

    platform.error = null;
    platform.answer = const [ConnectivityResult.wifi];
    await tester.pump(interval);
    expect(platform.checks, 3);
    expect(service.currentStatus, NetworkStatus.online);
    service.dispose();
  });

  testWidgets('replays the current state to a late subscriber', (tester) async {
    await start(tester, const [ConnectivityResult.none], listen: false);

    expect(await service.statusStream.first, NetworkStatus.offline);
    expect(await service.resultsStream.first, const [ConnectivityResult.none]);
    service.dispose();
  });
}
