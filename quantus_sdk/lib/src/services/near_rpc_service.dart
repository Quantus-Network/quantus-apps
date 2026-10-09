import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/constants/app_constants.dart';

/// The NEAR RPC refused or failed a view call.
class NearRpcException implements Exception {
  final String message;

  const NearRpcException(this.message);

  @override
  String toString() => 'NearRpcException: $message';
}

/// Read-only calls on NEAR contracts over JSON-RPC.
class NearRpcService {
  final http.Client _client;
  final Uri _endpoint;

  NearRpcService({http.Client? client, String endpoint = AppConstants.nearRpcEndpoint})
    : _client = client ?? http.Client(),
      _endpoint = Uri.parse(endpoint);

  /// Calls the view function [method] of [account] with JSON [args] and
  /// decodes the JSON it returns.
  Future<Object?> view(String account, String method, [Map<String, Object?> args = const {}]) async {
    final response = await _client.post(
      _endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': '1',
        'method': 'query',
        'params': {
          'request_type': 'call_function',
          'finality': 'final',
          'account_id': account,
          'method_name': method,
          'args_base64': base64Encode(utf8.encode(jsonEncode(args))),
        },
      }),
    );
    if (response.statusCode != 200) throw NearRpcException('HTTP ${response.statusCode}: ${response.body}');
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final result = json['result'] as Map<String, dynamic>?;
    final error = json['error'] ?? result?['error'];
    if (error != null) throw NearRpcException('$account.$method: $error');
    return jsonDecode(utf8.decode((result!['result'] as List<dynamic>).cast<int>()));
  }
}
