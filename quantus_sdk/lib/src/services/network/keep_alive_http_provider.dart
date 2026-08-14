import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:polkadart/polkadart.dart';

/// JSON-RPC over HTTP with connection reuse.
///
/// polkadart's `HttpProvider.send` uses the top-level `http.post`, which
/// creates a new client — and therefore a fresh TCP+TLS handshake — for every
/// request. This provider keeps one [http.Client] so repeated RPCs to the same
/// endpoint reuse pooled keep-alive connections.
class KeepAliveHttpProvider extends Provider {
  KeepAliveHttpProvider(this.url);

  final Uri url;
  final http.Client _client = http.Client();
  int _sequence = 0;

  @override
  Future<RpcResponse> send(String method, List<dynamic> params) async {
    final response = await _client.post(
      url,
      body: jsonEncode({'id': (++_sequence).toString(), 'jsonrpc': '2.0', 'method': method, 'params': params}),
      headers: {'Content-Type': 'application/json'},
    );
    final data = jsonDecode(response.body);
    return RpcResponse(id: int.tryParse(data['id'].toString()) ?? -1, result: data['result'], error: data['error']);
  }

  @override
  Future<SubscriptionResponse> subscribe(
    String method,
    List<dynamic> params, {
    FutureOr<void> Function(String subscription)? onCancel,
  }) {
    throw Exception('KeepAliveHttpProvider does not support subscriptions');
  }

  @override
  Future<void> connect() => Future.value();

  @override
  Future<void> disconnect() => Future.value();

  @override
  bool isConnected() => true;
}
