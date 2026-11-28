import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_desktop_wallet/generated/version.g.dart';
import 'package:quantus_desktop_wallet/services/desktop_telemetry.dart';
import 'package:quantus_desktop_wallet/services/telemetry_user_store.dart';

class _MemoryUserStore implements TelemetryUserStore {
  _MemoryUserStore(this.id);

  final String id;

  @override
  Future<String> userId() async => id;
}

class _BrokenUserStore implements TelemetryUserStore {
  @override
  Future<String> userId() async => throw const FileSystemException('unreadable');
}

/// What TelemetryDeck was sent, one request at a time.
class _Collector {
  final requests = <http.Request>[];

  /// What the next request is answered with; a thrown error when it throws.
  Future<http.Response> Function(http.Request request) answer = (_) async => http.Response('OK', 200);

  late final client = MockClient((request) {
    requests.add(request);
    return answer(request);
  });

  /// Every signal sent, in order.
  List<Map<String, dynamic>> get signals => [
    for (final request in requests) ...(jsonDecode(request.body) as List).cast<Map<String, dynamic>>(),
  ];

  /// The signals sent after the session's start.
  List<Map<String, dynamic>> get events => signals.where((s) => s['type'] != 'TelemetryDeck.Session.started').toList();
}

/// A server that takes the first request and never answers it, and answers
/// every later one at once.
class _StallingClient extends http.BaseClient {
  final types = <String>[];

  /// Whether the first request was aborted.
  var firstAborted = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().bytesToString();
    types.addAll([for (final signal in jsonDecode(body) as List) (signal as Map)['type'] as String]);
    if (types.length > 1) return http.StreamedResponse(Stream.value(utf8.encode('OK')), 200);
    if (request case http.Abortable(:final abortTrigger?)) unawaited(abortTrigger.then((_) => firstAborted = true));
    return Completer<http.StreamedResponse>().future;
  }
}

const _appId = '56C8354B-882C-4A7E-A50C-971B41F8010E';

DesktopTelemetry _telemetry(
  _Collector collector, {
  TelemetryUserStore? userStore,
  bool isTestMode = false,
  Map<String, String> parameters = const {'TelemetryDeck.AppInfo.version': '9.9.9'},
}) => DesktopTelemetry(
  client: collector.client,
  userStore: userStore ?? _MemoryUserStore('ABC'),
  appId: _appId,
  salt: 'QDay',
  isTestMode: isTestMode,
  parameters: parameters,
);

void main() {
  group('a signal', () {
    test('is posted to TelemetryDeck\'s v2 API as a JSON array of one signal', () async {
      final collector = _Collector();
      final telemetry = _telemetry(collector);

      telemetry.sendEvent('send_transfer');
      await telemetry.idle;

      expect(collector.requests, hasLength(2));
      for (final request in collector.requests) {
        expect(request.method, 'POST');
        expect(request.url, Uri.parse('https://nom.telemetrydeck.com/v2/'));
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(request.body), isA<List<dynamic>>().having((list) => list.length, 'length', 1));
      }
      final signal = collector.events.single;
      expect(
        signal.keys,
        unorderedEquals(['appID', 'clientUser', 'sessionID', 'type', 'receivedAt', 'isTestMode', 'payload']),
      );
      expect(signal['appID'], _appId);
      expect(signal['type'], 'send_transfer');
      expect(signal['isTestMode'], 'false');
      expect(signal['receivedAt'], matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\+0000$')));
      expect(signal['payload'], isA<Map<String, dynamic>>());
      expect((signal['payload'] as Map).values, everyElement(isA<String>()));
    });

    test('names its user by SHA-256 of the user ID and the salt, in lowercase hex', () async {
      final collector = _Collector();
      final telemetry = _telemetry(collector, userStore: _MemoryUserStore('ABC'));

      telemetry.sendEvent('send_transfer');
      await telemetry.idle;

      // Worked out apart from the app: sha256('ABCQDay').
      final expected = sha256.convert(utf8.encode('ABCQDay')).toString();
      expect(expected, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(collector.signals.map((s) => s['clientUser']), everyElement(expected));
    });

    test('is marked a test signal exactly when the app says it is a test build', () async {
      final debug = _Collector();
      final debugTelemetry = _telemetry(debug, isTestMode: true)..sendEvent('a');
      final release = _Collector();
      final releaseTelemetry = _telemetry(release, isTestMode: false)..sendEvent('a');
      await debugTelemetry.idle;
      await releaseTelemetry.idle;

      expect(debug.signals.map((s) => s['isTestMode']), everyElement('true'));
      expect(release.signals.map((s) => s['isTestMode']), everyElement('false'));
    });

    test('carries the standard parameters beside the event\'s own', () async {
      final collector = _Collector();
      final telemetry = DesktopTelemetry(
        client: collector.client,
        userStore: _MemoryUserStore('ABC'),
        appId: _appId,
        salt: 'QDay',
        isTestMode: false,
      );

      telemetry.sendEvent('swap_started', parameters: {'token': 'USDC'});
      await telemetry.idle;

      final payload = collector.events.single['payload'] as Map<String, dynamic>;
      final os = switch (Platform.operatingSystem) {
        'macos' => 'macOS',
        'windows' => 'Windows',
        'linux' => 'Linux',
        _ => fail('not a desktop platform'),
      };
      expect(payload, {
        'TelemetryDeck.AppInfo.version': appVersion,
        'TelemetryDeck.AppInfo.buildNumber': appBuildNumber,
        'TelemetryDeck.Device.operatingSystem': os,
        'TelemetryDeck.Device.systemVersion': startsWith('$os '),
        'TelemetryDeck.RunContext.locale': Platform.localeName,
        'token': 'USDC',
      });
    });

    test('names the system version as the OS and its dotted version, as the phone does', () {
      expect(telemetrySystemVersion('macOS', 'Version 15.1 (Build 24B83)'), 'macOS 15.1');
      expect(telemetrySystemVersion('Windows', '"Windows 10 Pro" 10.0 (Build 19045)'), 'Windows 10.0');
      expect(telemetrySystemVersion('Linux', '6.5.0-35-generic #35-Ubuntu SMP'), 'Linux 6.5.0');
      // Nothing dotted in it: the text as the system gave it.
      expect(telemetrySystemVersion('Linux', 'unknown'), 'Linux unknown');
    });
  });

  group('a launch', () {
    test('starts its session with TelemetryDeck.Session.started, before anything else', () async {
      final collector = _Collector();
      final telemetry = _telemetry(collector);

      telemetry.sendEvent('first');
      telemetry.sendEvent('second');
      await telemetry.idle;

      expect(collector.signals.map((s) => s['type']), ['TelemetryDeck.Session.started', 'first', 'second']);
    });

    test('sends its session start even when nothing else is sent', () async {
      final collector = _Collector();
      final telemetry = _telemetry(collector);
      await telemetry.idle;

      expect(collector.signals.map((s) => s['type']), ['TelemetryDeck.Session.started']);
    });

    test('keeps one session ID for all its signals, and the next launch has another', () async {
      final store = _MemoryUserStore('ABC');
      final first = _Collector();
      final firstLaunch = _telemetry(first, userStore: store)
        ..sendEvent('a')
        ..sendEvent('b');
      final second = _Collector();
      final secondLaunch = _telemetry(second, userStore: store)..sendEvent('a');
      await firstLaunch.idle;
      await secondLaunch.idle;

      final firstSessions = first.signals.map((s) => s['sessionID']).toSet();
      final secondSessions = second.signals.map((s) => s['sessionID']).toSet();
      expect(firstSessions, hasLength(1));
      expect(secondSessions, hasLength(1));
      expect(firstSessions.single, isNot(secondSessions.single));
      expect(firstSessions.single, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('is the same user as the launch before it', () async {
      final store = _MemoryUserStore('ABC');
      final first = _Collector();
      final second = _Collector();
      final firstLaunch = _telemetry(first, userStore: store);
      final secondLaunch = _telemetry(second, userStore: store);
      await firstLaunch.idle;
      await secondLaunch.idle;

      expect(first.signals.single['clientUser'], second.signals.single['clientUser']);
    });
  });

  group('a signal that cannot be sent', () {
    testWidgets('a response that never comes is given up after 30 seconds, its request aborted, and the next goes', (
      tester,
    ) async {
      final client = _StallingClient();
      DesktopTelemetry(
        client: client,
        userStore: _MemoryUserStore('ABC'),
        appId: _appId,
        salt: 'QDay',
        isTestMode: false,
        parameters: const {},
      ).sendEvent('next');
      await tester.pump();
      expect(client.types, ['TelemetryDeck.Session.started']);

      await tester.pump(const Duration(seconds: 29));
      expect(client.types, ['TelemetryDeck.Session.started']);
      expect(client.firstAborted, isFalse);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(client.types, ['TelemetryDeck.Session.started', 'next']);
      expect(client.firstAborted, isTrue);
    });

    test('a send that fails to connect raises nothing, and the next signal still goes', () async {
      final collector = _Collector();
      collector.answer = (request) async => throw http.ClientException('Connection refused', request.url);
      final telemetry = _telemetry(collector);
      telemetry.sendEvent('lost');
      await telemetry.idle;

      collector.answer = (_) async => http.Response('OK', 200);
      telemetry.sendEvent('sent');
      await telemetry.idle;

      expect(collector.signals.map((s) => s['type']), ['TelemetryDeck.Session.started', 'lost', 'sent']);
    });

    test('a signal TelemetryDeck refuses raises nothing, and the next signal still goes', () async {
      final collector = _Collector();
      collector.answer = (_) async => http.Response('Unprocessable', 422);
      final telemetry = _telemetry(collector);
      telemetry.sendEvent('refused');
      await telemetry.idle;

      collector.answer = (_) async => http.Response('OK', 200);
      telemetry.sendEvent('sent');
      await telemetry.idle;

      expect(collector.events.map((s) => s['type']), ['refused', 'sent']);
    });

    test('a user ID that cannot be read raises nothing, and nothing is sent without it', () async {
      final collector = _Collector();
      final telemetry = _telemetry(collector, userStore: _BrokenUserStore());

      telemetry.sendEvent('a');
      telemetry.sendError('b', error: StateError('x'));
      await telemetry.idle;

      expect(collector.requests, isEmpty);
    });
  });

  group('an error', () {
    test('is sent as Error with its name and its type, never its text', () async {
      final collector = _Collector();
      final telemetry = _telemetry(collector);

      telemetry.sendError('Keystone signature processing failed', error: StateError('to qzSecretAddress'));
      await telemetry.idle;

      final signal = collector.events.single;
      expect(signal['type'], 'Error');
      expect(signal['payload'], {
        'TelemetryDeck.AppInfo.version': '9.9.9',
        'errorName': 'Keystone signature processing failed',
        'error': 'StateError',
      });
      expect(collector.requests.map((r) => r.body), everyElement(isNot(contains('qzSecretAddress'))));
    });
  });
}
