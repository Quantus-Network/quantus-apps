import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/swap_live_activity.dart';

/// Tells Senoti about the card so it can keep sending updates after the app
/// is suspended.
abstract class SwapLiveActivityRegistrar {
  Future<void> register({required String token, required String platform, required SwapLiveActivityContent content});

  Future<void> unregister(String token);
}

/// A non-202 answer is thrown. Callers log it and leave the card up, because
/// the card itself does not depend on the registration.
///
/// [timeout] bounds the wait. Senoti accepting the socket and then staying
/// silent completes with [TimeoutException] instead of holding the caller.
class SwapLiveActivityPush implements SwapLiveActivityRegistrar {
  final http.Client? _client;
  final String endpoint;
  final Duration timeout;

  SwapLiveActivityPush({
    http.Client? client,
    this.endpoint = AppConstants.senotiEndpoint,
    this.timeout = swapLiveRemoteTimeout,
  }) : _client = client;

  @override
  Future<void> register({
    required String token,
    required String platform,
    required SwapLiveActivityContent content,
  }) async {
    final response = await _send(
      (client) => client.post(
        Uri.parse('$endpoint/swap-activities'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(swapLiveActivityRegistrationBody(token: token, platform: platform, content: content)),
      ),
    );
    if (response.statusCode != 202) {
      throw Exception('swap activity register failed: ${response.statusCode} ${response.body}');
    }
  }

  @override
  Future<void> unregister(String token) async {
    final response = await _send(
      (client) => client.delete(
        Uri.parse('$endpoint/swap-activities'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'activity_token': token}),
      ),
    );
    if (response.statusCode != 202) {
      throw Exception('swap activity unregister failed: ${response.statusCode} ${response.body}');
    }
  }

  /// Uses the injected client when tests supply one. Otherwise each call gets
  /// a client that is closed when it finishes, including on timeout, so the
  /// socket does not stay open after the caller has moved on.
  Future<http.Response> _send(Future<http.Response> Function(http.Client client) issue) async {
    final owned = _client == null;
    final client = _client ?? http.Client();
    try {
      return await issue(client).timeout(timeout);
    } on TimeoutException {
      if (owned) client.close();
      throw TimeoutException('Senoti did not answer', timeout);
    } finally {
      if (owned) client.close();
    }
  }
}
