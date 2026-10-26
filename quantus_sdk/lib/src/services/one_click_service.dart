import 'dart:convert';

import 'package:http/http.dart' as http;

/// 1Click answered [statusCode] with [message].
class SwapApiException implements Exception {
  final int statusCode;
  final String message;

  const SwapApiException(this.statusCode, this.message);

  @override
  String toString() => 'SwapApiException($statusCode): $message';
}

/// Transport for the NEAR Intents 1Click API at [endpoint]: our proxy, which
/// adds the partner key itself, or 1Click directly with [apiKey] sent as
/// X-API-Key. Both come from remote config and nowhere else; until an
/// endpoint is served every request fails. An answer outside 2xx becomes a
/// [SwapApiException].
class OneClickService {
  /// Longest any request may take before it fails.
  static const requestTimeout = Duration(seconds: 30);

  /// Longest a recipient lookup may hold up the send flow.
  static const depositLookupTimeout = Duration(seconds: 10);

  final http.Client _client;
  final Uri? _base;
  final String? _apiKey;

  /// Answers so far. A deposit address is one for good, and 1Click never
  /// issues an address that already exists, so neither answer goes stale.
  final _depositAddresses = <String, bool>{};

  /// The last answer to each GET with its ETag, so asking again costs a 304
  /// and no body while the resource is unchanged.
  final _etagged = <Uri, (String, Object?)>{};

  OneClickService({http.Client? client, required String? endpoint, String? apiKey})
    : _client = client ?? http.Client(),
      _base = endpoint == null ? null : Uri.parse(endpoint.replaceFirst(RegExp(r'/+$'), '')),
      _apiKey = apiKey;

  /// Whether 1Click issued [address] as the deposit address of a swap funded
  /// on its origin chain. Such an address takes exactly the one deposit its
  /// quote expects. Each address is asked about once. The history route is
  /// invite-only: a 403 from 1Click is thrown, never read as "not a deposit".
  Future<bool> isDepositAddress(String address) async {
    final known = _depositAddresses[address];
    if (known != null) return known;
    final json = await send(
      'GET',
      '/v0/account/history',
      query: {'depositAddress': address, 'depositType': 'ORIGIN_CHAIN', 'limit': '1'},
    ).timeout(depositLookupTimeout);
    return _depositAddresses[address] = ((json as Map<String, dynamic>)['items'] as List<dynamic>).isNotEmpty;
  }

  Future<Object?> send(String method, String path, {Map<String, Object>? body, Map<String, String>? query}) async {
    final base = _base;
    if (base == null) throw StateError('No 1Click endpoint is configured');
    final uri = base.replace(path: '${base.path}$path', queryParameters: query);
    final cached = method == 'GET' ? _etagged[uri] : null;
    final headers = {'Content-Type': 'application/json', 'X-API-Key': ?_apiKey, 'If-None-Match': ?cached?.$1};
    final response =
        await (method == 'GET'
                ? _client.get(uri, headers: headers)
                : _client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(requestTimeout);
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
