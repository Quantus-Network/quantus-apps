import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('ChainRpc');

class ChainInfo {
  final int peerCount;
  final int currentBlock;
  final int? targetBlock;
  final bool isSyncing;
  final String chainName;
  final String nodeVersion;

  ChainInfo({
    required this.peerCount,
    required this.currentBlock,
    this.targetBlock,
    required this.isSyncing,
    required this.chainName,
    required this.nodeVersion,
  });

  @override
  String toString() {
    return 'ChainInfo(peers: $peerCount, block: $currentBlock/$targetBlock, syncing: $isSyncing, chain: $chainName)';
  }
}

class ChainRpcClient {
  final String rpcUrl;
  final Duration timeout;
  final http.Client _httpClient;
  int _requestId = 1;

  ChainRpcClient({String? rpcUrl, this.timeout = const Duration(seconds: 10)})
    : rpcUrl = rpcUrl ?? MinerConfig.nodeRpcUrl(MinerConfig.defaultNodeRpcPort),
      _httpClient = http.Client();

  /// Get comprehensive chain information
  Future<ChainInfo?> getChainInfo() async {
    try {
      // Only print when successfully starting RPC calls
      // print('DEBUG: Starting RPC calls to $rpcUrl');

      // Execute multiple RPC calls in parallel for efficiency
      final futures = await Future.wait([
        _rpcCall('peer_getBasicInfo'),
        _rpcCall('chain_getHeader'),
        _rpcCall('system_chain'),
        _rpcCall('system_version'),
        _rpcCall('system_syncState'),
      ]);

      // print('DEBUG: RPC calls completed');

      final peerResult = futures[0];
      final headerResult = futures[1];
      final chainResult = futures[2];
      final versionResult = futures[3];
      final syncStateResult = futures[4];

      // Extract peer count from custom peer_getBasicInfo
      int peerCount = 0;
      // print('DEBUG: peer_getBasicInfo result: $peerResult');
      if (peerResult != null && peerResult['peer_count'] != null) {
        peerCount = peerResult['peer_count'] as int;
      }
      // print('DEBUG: Extracted peer count: $peerCount');

      // Extract current block from chain_getHeader
      int currentBlock = 0;
      // print('DEBUG: chain_getHeader result: $headerResult');
      if (headerResult != null && headerResult['number'] != null) {
        final blockHex = headerResult['number'] as String;
        currentBlock = _hexToInt(blockHex);
      }
      // print('DEBUG: Extracted current block: $currentBlock');

      // Extract chain name
      String chainName = 'Quantus';
      if (chainResult != null) {
        chainName = chainResult as String;
      }

      // Extract node version
      String nodeVersion = 'Unknown';
      if (versionResult != null) {
        nodeVersion = versionResult as String;
      }

      // Extract sync state - try system_syncState, fallback to estimation
      bool isSyncing = false;
      int? targetBlock;
      if (syncStateResult != null) {
        if (syncStateResult['currentBlock'] != null && syncStateResult['highestBlock'] != null) {
          final current = syncStateResult['currentBlock'] as int;
          final highest = syncStateResult['highestBlock'] as int;

          // Update current block if more recent than header
          if (current > currentBlock) {
            currentBlock = current;
          }

          targetBlock = highest;
          // Consider syncing if more than 5 blocks behind
          isSyncing = (highest - current) > 5;
        }
      } else {
        // Fallback: assume not syncing if we can't get sync state
        targetBlock = currentBlock;
        isSyncing = false;
      }

      final info = ChainInfo(
        peerCount: peerCount,
        currentBlock: currentBlock,
        targetBlock: targetBlock,
        isSyncing: isSyncing,
        chainName: chainName,
        nodeVersion: nodeVersion,
      );

      _log.d('Chain connected - Peers: $peerCount, Block: $currentBlock');
      return info;
    } catch (e) {
      // Only log unexpected errors, not connection issues during startup
      if (!e.toString().contains('Connection refused') &&
          !e.toString().contains('Connection reset') &&
          !e.toString().contains('timeout')) {
        _log.w('getChainInfo error', error: e);
      }
      return null;
    }
  }

  /// Get just the peer count (lightweight call)
  Future<int?> getPeerCount() async {
    try {
      final result = await _rpcCall('peer_getBasicInfo');
      if (result != null && result['peer_count'] != null) {
        return result['peer_count'] as int;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get current block height
  Future<int?> getCurrentBlock() async {
    try {
      final result = await _rpcCall('chain_getHeader');
      if (result != null && result['number'] != null) {
        final blockHex = result['number'] as String;
        return _hexToInt(blockHex);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get sync state information
  Future<Map<String, dynamic>?> getSyncState() async {
    try {
      return await _rpcCall('system_syncState');
    } catch (e) {
      return null;
    }
  }

  /// Check if the node is syncing
  Future<bool?> isSyncing() async {
    try {
      final syncState = await _rpcCall('system_syncState');
      if (syncState != null && syncState['currentBlock'] != null && syncState['highestBlock'] != null) {
        final current = syncState['currentBlock'] as int;
        final highest = syncState['highestBlock'] as int;
        return (highest - current) > 5;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Test if RPC endpoint is reachable
  Future<bool> isReachable() async {
    try {
      // Try the custom peer endpoint since it's definitely available
      final result = await _rpcCall('peer_getBasicInfo');
      return result != null;
    } catch (e) {
      return false;
    }
  }

  /// Execute a JSON-RPC call
  Future<dynamic> _rpcCall(String method, [List<dynamic>? params]) async {
    final request = {'jsonrpc': '2.0', 'id': _requestId++, 'method': method, 'params': ?params};

    // Only print RPC calls when debugging connection issues
    // print('DEBUG: Making RPC call: $method with request: ${json.encode(request)}');

    final response = await _httpClient
        .post(Uri.parse(rpcUrl), headers: {'Content-Type': 'application/json'}, body: json.encode(request))
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Only print successful responses when debugging
      // print('DEBUG: RPC response for $method: $data');
      if (data['error'] != null) {
        throw Exception('RPC error: ${data['error']['message']}');
      }
      return data['result'];
    } else {
      // Don't log connection errors during startup - they're expected
      if (response.statusCode != 0) {
        _log.w('RPC HTTP error for $method: ${response.statusCode} ${response.reasonPhrase}');
      }
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
  }

  /// Convert hex string to integer
  int _hexToInt(String hex) {
    // Remove '0x' prefix if present
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }
    return int.parse(hex, radix: 16);
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

/// Polling RPC client that provides continuous updates
class PollingChainRpcClient extends ChainRpcClient {
  Timer? _pollTimer;
  Duration pollInterval;

  // Callbacks
  void Function(ChainInfo info)? onChainInfoUpdate;
  void Function(String error)? onError;

  PollingChainRpcClient({super.rpcUrl, super.timeout, Duration? pollInterval})
    : pollInterval = pollInterval ?? MinerConfig.prometheusPollingInterval;

  /// Start polling for chain information
  void startPolling() {
    stopPolling();
    _pollTimer = Timer.periodic(pollInterval, (_) => _pollChainInfo());
  }

  /// Stop polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Check if currently polling
  bool get isPolling => _pollTimer?.isActive == true;

  /// Internal polling method
  Future<void> _pollChainInfo() async {
    try {
      final info = await getChainInfo();
      if (info != null) {
        onChainInfoUpdate?.call(info);
      } else {
        // Only report non-connection errors
        onError?.call('Failed to get chain information');
      }
    } catch (e) {
      // Filter out expected connection errors during startup
      final errorMessage = e.toString();
      if (!errorMessage.contains('Connection refused') &&
          !errorMessage.contains('Connection reset') &&
          !errorMessage.contains('timeout')) {
        onError?.call('RPC polling error: $e');
      }
      // Silently continue for connection errors - they're expected during startup
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
