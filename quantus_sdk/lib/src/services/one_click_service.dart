import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/constants/app_constants.dart';

/// 1Click answered [statusCode] with [message].
class SwapApiException implements Exception {
  final int statusCode;
  final String message;

  const SwapApiException(this.statusCode, this.message);

  @override
  String toString() => 'SwapApiException($statusCode): $message';
}

/// Transport for the NEAR Intents 1Click API: every request carries the
/// partner key, and an answer outside 2xx becomes a [SwapApiException].
class OneClickService {
  /// Longest a recipient lookup may hold up the send flow.
  static const depositLookupTimeout = Duration(seconds: 10);

  final http.Client _client;
  final Uri _base;
  final String? _apiKey;

  OneClickService({http.Client? client, String endpoint = AppConstants.oneClickEndpoint, String? apiKey})
    : _client = client ?? http.Client(),
      _base = Uri.parse(endpoint),
      _apiKey = apiKey;

  /// Whether 1Click issued [address] as the deposit address of a swap funded
  /// on its origin chain. Such an address takes exactly the one deposit its
  /// quote expects. The history route is invite-only: without the partner
  /// key 1Click answers 403, which is thrown, never read as "not a deposit".
  Future<bool> isDepositAddress(String address) async {
    final json = await send(
      'GET',
      '/v0/account/history',
      query: {'depositAddress': address, 'depositType': 'ORIGIN_CHAIN', 'limit': '1'},
    ).timeout(depositLookupTimeout);
    return ((json as Map<String, dynamic>)['items'] as List<dynamic>).isNotEmpty;
  }

  Future<Object?> send(String method, String path, {Map<String, Object>? body, Map<String, String>? query}) async {
    final uri = _base.replace(path: path, queryParameters: query);
    final headers = {'Content-Type': 'application/json', 'X-API-Key': ?_apiKey};
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.post(uri, headers: headers, body: jsonEncode(body));
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    Object? json;
    try {
      json = jsonDecode(response.body);
    } on FormatException {
      if (ok) rethrow;
    }
    if (!ok) {
      final message = json is Map ? json['message'] : null;
      throw SwapApiException(response.statusCode, switch (message) {
        String s => s,
        List l => l.join(', '),
        _ => response.body,
      });
    }
    return json;
  }
}
