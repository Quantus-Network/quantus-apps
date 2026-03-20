import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:quantus_sdk/quantus_sdk.dart';

class TxWatchTransfer {
  final String txHash;
  final String from;
  final String amount;
  final int? assetId;

  const TxWatchTransfer({required this.txHash, required this.from, required this.amount, this.assetId});

  factory TxWatchTransfer.fromJson(Map<String, dynamic> json) => TxWatchTransfer(
    txHash: json['tx_hash'] as String,
    from: json['from'] as String,
    amount: json['amount'] as String,
    assetId: json['asset_id'] as int?,
  );
}

class TxWatchService {
  WebSocket? _ws;
  String? _subscriptionId;
  int _idCounter = 1;

  static String _toWsUrl(String httpUrl) {
    return httpUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
  }

  Future<void> watch({
    required String address,
    required void Function(TxWatchTransfer) onTransfer,
    void Function(Object)? onError,
  }) async {
    final wsUrl = _toWsUrl(RpcEndpointService().bestEndpointUrl);
    try {
      _ws = await WebSocket.connect(wsUrl);
    } catch (e) {
      onError?.call(e);
      return;
    }

    _ws!.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': _idCounter++,
      'method': 'txWatch_watchAddress',
      'params': [address],
    }));

    _ws!.listen(
      (event) {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        if (data.containsKey('result') && _subscriptionId == null) {
          _subscriptionId = data['result'] as String;
          return;
        }
        if (data['method'] == 'txWatch_transfer' && data['params']?['subscription'] == _subscriptionId) {
          onTransfer(TxWatchTransfer.fromJson(data['params']['result'] as Map<String, dynamic>));
        }
        if (data.containsKey('error')) {
          onError?.call(Exception((data['error'] as Map<String, dynamic>)['message']));
        }
      },
      onError: (e) => onError?.call(e as Object),
    );
  }

  void dispose() {
    if (_subscriptionId != null && _ws != null) {
      try {
        _ws!.add(jsonEncode({
          'jsonrpc': '2.0',
          'id': _idCounter++,
          'method': 'txWatch_unwatchAddress',
          'params': [_subscriptionId],
        }));
      } catch (_) {}
    }
    _ws?.close();
    _ws = null;
    _subscriptionId = null;
  }
}
