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

  /// Answers so far. A deposit address is one for good, and 1Click never
  /// issues an address that already exists, so neither answer goes stale.
  final _depositAddresses = <String, bool>{};

  /// The last answer to each GET with its ETag, so asking again costs a 304
  /// and no body while the resource is unchanged.
  final _etagged = <Uri, (String, Object?)>{};

  OneClickService({http.Client? client, String endpoint = AppConstants.oneClickEndpoint, String? apiKey})
    : _client = client ?? http.Client(),
      _base = Uri.parse(endpoint),
      _apiKey = apiKey;

  /// Whether 1Click issued [address] as the deposit address of a swap funded
  /// on its origin chain. Such an address takes exactly the one deposit its
  /// quote expects. Each address is asked about once. The history route is
  /// invite-only: a lookup without the partner key is refused before any
  /// request, and a 403 from 1Click is thrown, never read as "not a deposit".
  Future<bool> isDepositAddress(String address) async {
    final known = _depositAddresses[address];
    if (known != null) return known;
    if (_apiKey == null) throw StateError('1Click history is invite-only and no partner key is configured');
    final json = await send(
      'GET',
      '/v0/account/history',
      query: {'depositAddress': address, 'depositType': 'ORIGIN_CHAIN', 'limit': '1'},
    ).timeout(depositLookupTimeout);
    return _depositAddresses[address] = ((json as Map<String, dynamic>)['items'] as List<dynamic>).isNotEmpty;
  }

  Future<Object?> send(String method, String path, {Map<String, Object>? body, Map<String, String>? query}) async {
    final uri = _base.replace(path: path, queryParameters: query);
    final cached = method == 'GET' ? _etagged[uri] : null;
    final headers = {'Content-Type': 'application/json', 'X-API-Key': ?_apiKey, 'If-None-Match': ?cached?.$1};
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.post(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 304 && cached != null) return cached.$2;
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
    final etag = response.headers['etag'];
    if (method == 'GET' && etag != null) _etagged[uri] = (etag, json);
    return json;
  }
}
