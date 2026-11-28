import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:quantus_desktop_wallet/generated/version.g.dart';
import 'package:quantus_desktop_wallet/services/telemetry_user_store.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:uuid/uuid.dart';
import 'package:wallet_core/services/telemetry.dart';

/// Where the desktop app's signals go: the TelemetryDeck app of its own.
const desktopTelemetryAppId = '56C8354B-882C-4A7E-A50C-971B41F8010E';

/// The phone's salt, so that the two apps hash their users alike.
const desktopTelemetrySalt = 'QDay';

/// Sends the app's analytics to TelemetryDeck through its HTTP API, as its
/// Swift SDK does on the phone: TelemetryDeck has no SDK for Windows or Linux.
///
/// One instance is one launch's session: it has its own session ID, and its
/// first signal is `TelemetryDeck.Session.started`. Signals go one at a time,
/// in the order they were sent.
///
/// A signal that cannot be sent is dropped and named in the debug log only:
/// analytics must never get in the way of the wallet.
class DesktopTelemetry implements Telemetry {
  DesktopTelemetry({
    required http.Client client,
    required TelemetryUserStore userStore,
    required this.appId,
    required this.salt,
    required this.isTestMode,
    Map<String, String>? parameters,
  }) : _client = client,
       _userStore = userStore,
       _parameters = parameters ?? standardTelemetryParameters() {
    _send('TelemetryDeck.Session.started', const {});
  }

  static final _endpoint = Uri.parse('https://nom.telemetrydeck.com/v2/');

  /// How long a signal may take to be sent. A request still unanswered then
  /// is aborted and its signal dropped: the signals after it wait for it.
  static const requestTimeout = Duration(seconds: 30);

  final String appId;
  final String salt;

  /// Whether the signals are test signals, which TelemetryDeck keeps apart.
  final bool isTestMode;

  final http.Client _client;
  final TelemetryUserStore _userStore;
  final Map<String, String> _parameters;
  final _sessionId = const Uuid().v4();
  Future<String>? _clientUser;
  Future<void> _queue = Future.value();

  /// Done once every signal sent so far has been sent or dropped.
  @visibleForTesting
  Future<void> get idle => _queue;

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) => _send(eventName, parameters ?? const {});

  /// As the phone's: the error's name and its type, never its text.
  @override
  void sendError(String errorName, {required Object error}) =>
      _send('Error', {'errorName': errorName, 'error': error.runtimeType.toString()});

  void _send(String type, Map<String, String> parameters) {
    final receivedAt = clock.now();
    _queue = _queue.then((_) => _post(type, parameters, receivedAt));
  }

  Future<void> _post(String type, Map<String, String> parameters, DateTime receivedAt) async {
    try {
      final signal = {
        'appID': appId,
        'clientUser': await (_clientUser ??= _hashedUser()),
        'sessionID': _sessionId,
        'type': type,
        'receivedAt': _formatReceivedAt(receivedAt),
        'isTestMode': '$isTestMode',
        'payload': {..._parameters, ...parameters},
      };
      final abort = Completer<void>();
      final request = http.AbortableRequest('POST', _endpoint, abortTrigger: abort.future)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode([signal]);
      final http.Response response;
      try {
        response = await _client.send(request).then(http.Response.fromStream).timeout(requestTimeout);
      } on TimeoutException {
        // Frees the connection; the request's own late failure is ignored.
        abort.complete();
        rethrow;
      }
      if (response.statusCode != 200) quantusPrint('Telemetry signal $type refused: ${response.statusCode}');
    } catch (e) {
      quantusPrint('Telemetry signal $type not sent: $e');
    }
  }

  /// SHA-256 of the user ID and the salt, as the Swift SDK hashes it.
  Future<String> _hashedUser() async => sha256.convert(utf8.encode('${await _userStore.userId()}$salt')).toString();

  /// The Swift SDK's form: `yyyy-MM-dd'T'HH:mm:ssZ` in UTC.
  static String _formatReceivedAt(DateTime at) {
    final utc = at.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)}'
        'T${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}+0000';
  }
}

/// What every signal carries, under the names TelemetryDeck's SDKs use.
Map<String, String> standardTelemetryParameters() {
  final os = switch (Platform.operatingSystem) {
    'macos' => 'macOS',
    'windows' => 'Windows',
    'linux' => 'Linux',
    final other => other,
  };
  return {
    'TelemetryDeck.AppInfo.version': appVersion,
    'TelemetryDeck.AppInfo.buildNumber': appBuildNumber,
    'TelemetryDeck.Device.operatingSystem': os,
    'TelemetryDeck.Device.systemVersion': telemetrySystemVersion(os, Platform.operatingSystemVersion),
    'TelemetryDeck.RunContext.locale': Platform.localeName,
  };
}

/// [os] and the dotted version in the system's own description of itself
/// ([version]), as the phone's "iOS 18.1.0"; the description whole when it
/// has none.
String telemetrySystemVersion(String os, String version) =>
    '$os ${RegExp(r'\d+(\.\d+)+').firstMatch(version)?.group(0) ?? version}';

/// The connection the signals go out on.
final telemetryHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// The app's analytics, bound to wallet_core's [telemetryProvider].
final desktopTelemetryProvider = Provider<Telemetry>(
  (ref) => DesktopTelemetry(
    client: ref.watch(telemetryHttpClientProvider),
    userStore: ref.watch(telemetryUserStoreProvider),
    appId: desktopTelemetryAppId,
    salt: desktopTelemetrySalt,
    isTestMode: kDebugMode,
  ),
);
