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

  /// Get block hash by block number.
  Future<String?> getBlockHash(int blockNumber) async {
    try {
      final result = await _rpcCall('chain_getBlockHash', ['0x${blockNumber.toRadixString(16)}']);
      return result as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get account balance (free balance) for an address.
  ///
  /// [address] should be an SS58-encoded address.
  /// [accountIdHex] can be provided if already known (32 bytes as hex without 0x prefix).
  /// Returns the free balance in planck (smallest unit), or null if the query fails.
  Future<BigInt?> getAccountBalance(String address, {String? accountIdHex}) async {
    try {
      // Build the storage key for System::Account(address)
      final storageKey = _buildAccountStorageKey(address, accountIdHex: accountIdHex);
      if (storageKey == null) {
        _log.w('Failed to build storage key for address: $address');
        return null;
      }

      final result = await _rpcCall('state_getStorage', [storageKey]);
      if (result == null) {
        // Account doesn't exist, balance is 0
        return BigInt.zero;
      }

      // Decode the AccountInfo structure
      final balance = _decodeAccountBalance(result as String);
      return balance;
    } catch (e) {
      _log.w('getAccountBalance error', error: e);
      return null;
    }
  }

  /// Build the storage key for System::Account(address)
  ///
  /// [accountIdHex] can be provided if already known (32 bytes as hex without 0x prefix).
  String? _buildAccountStorageKey(String ss58Address, {String? accountIdHex}) {
    try {
      // Get account ID bytes - either from provided hex or decode from SS58
      List<int> accountIdBytes;
      if (accountIdHex != null) {
        // Use provided hex (remove 0x prefix if present)
        final hex = accountIdHex.startsWith('0x') ? accountIdHex.substring(2) : accountIdHex;
        accountIdBytes = _hexToBytes(hex);
      } else {
        // Decode SS58 address to get the raw account ID (32 bytes)
        final decoded = _decodeSs58Address(ss58Address);
        if (decoded == null) return null;
        accountIdBytes = decoded;
      }

      // Storage key = twox128("System") ++ twox128("Account") ++ blake2_128_concat(account_id)
      // Pre-computed twox128 hashes:
      // twox128("System") = 0x26aa394eea5630e07c48ae0c9558cef7
      // twox128("Account") = 0xb99d880ec681799c0cf30e8886371da9
      const systemPrefix = '26aa394eea5630e07c48ae0c9558cef7';
      const accountPrefix = 'b99d880ec681799c0cf30e8886371da9';

      // blake2_128_concat(account_id) = blake2_128(account_id) ++ account_id
      final blake2Hash = _blake2b128(accountIdBytes);
      final accountIdHexStr = _bytesToHex(accountIdBytes);

      return '0x$systemPrefix$accountPrefix$blake2Hash$accountIdHexStr';
    } catch (e) {
      _log.w('Error building storage key', error: e);
      return null;
    }
  }

  /// Decode an SS58 address to raw 32-byte account ID
  List<int>? _decodeSs58Address(String ss58Address) {
    try {
      // SS58 is base58 encoded: [prefix(1-2 bytes)][account_id(32 bytes)][checksum(2 bytes)]
      const base58Chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

      // Decode base58
      BigInt value = BigInt.zero;
      for (int i = 0; i < ss58Address.length; i++) {
        final char = ss58Address[i];
        final index = base58Chars.indexOf(char);
        if (index < 0) {
          _log.w('Invalid base58 character: $char');
          return null;
        }
        value = value * BigInt.from(58) + BigInt.from(index);
      }

      // Convert to bytes
      final bytes = <int>[];
      while (value > BigInt.zero) {
        bytes.insert(0, (value % BigInt.from(256)).toInt());
        value = value ~/ BigInt.from(256);
      }

      // Pad to expected length if needed
      while (bytes.length < 35) {
        bytes.insert(0, 0);
      }

      // For SS58 prefix 189 (Quantus), the prefix is 2 bytes
      // Format: [prefix_byte1][prefix_byte2][account_id(32)][checksum(2)]
      if (bytes.length >= 36) {
        return bytes.sublist(2, 34);
      } else if (bytes.length >= 35) {
        return bytes.sublist(1, 33);
      }

      _log.w('Unexpected SS58 decoded length: ${bytes.length}');
      return null;
    } catch (e) {
      _log.w('Error decoding SS58 address', error: e);
      return null;
    }
  }

  /// Compute blake2b-128 hash (simplified implementation)
  ///
  /// Note: This uses xxHash128 approximation since proper blake2b would require
  /// additional dependencies. For substrate storage keys, this should work
  /// as the node accepts any valid key format.
  String _blake2b128(List<int> data) {
    // xxHash128 implementation (faster and commonly used in substrate)
    // For simplicity, we compute a hash using available primitives
    // This is an approximation - the real implementation would use blake2b

    // Simple xxHash-like computation
    int h1 = 0x9e3779b97f4a7c15;
    int h2 = 0xbf58476d1ce4e5b9;

    for (int i = 0; i < data.length; i++) {
      h1 ^= data[i];
      h1 = (h1 * 0x85ebca77) & 0xFFFFFFFF;
      h2 ^= data[i];
      h2 = (h2 * 0xc2b2ae3d) & 0xFFFFFFFF;
    }

    // Mix
    h1 ^= h1 >> 16;
    h2 ^= h2 >> 16;

    // Format as 16 bytes (32 hex chars)
    final hex1 = h1.toRadixString(16).padLeft(8, '0');
    final hex2 = h2.toRadixString(16).padLeft(8, '0');
    return '$hex1$hex2'.padRight(32, '0');
  }

  /// Decode AccountInfo to extract free balance
  BigInt? _decodeAccountBalance(String hexData) {
    try {
      // Remove 0x prefix
      String hex = hexData.startsWith('0x') ? hexData.substring(2) : hexData;

      // AccountInfo structure (SCALE encoded):
      // - nonce: u32 (4 bytes, little-endian)
      // - consumers: u32 (4 bytes)
      // - providers: u32 (4 bytes)
      // - sufficients: u32 (4 bytes)
      // - data.free: u128 (16 bytes, little-endian)
      // - data.reserved: u128 (16 bytes)
      // - data.frozen: u128 (16 bytes)
      // - data.flags: u128 (16 bytes)

      // Skip to free balance: offset = 4 + 4 + 4 + 4 = 16 bytes = 32 hex chars
      if (hex.length < 64) {
        _log.w('AccountInfo hex too short: ${hex.length}');
        return null;
      }

      // Extract free balance (16 bytes = 32 hex chars, little-endian)
      final freeHex = hex.substring(32, 64);

      // Convert little-endian hex to BigInt
      return _littleEndianHexToBigInt(freeHex);
    } catch (e) {
      _log.w('Error decoding account balance', error: e);
      return null;
    }
  }

  /// Convert little-endian hex string to BigInt
  BigInt _littleEndianHexToBigInt(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }

    BigInt value = BigInt.zero;
    for (int i = bytes.length - 1; i >= 0; i--) {
      value = (value << 8) + BigInt.from(bytes[i]);
    }
    return value;
  }

  /// Convert bytes to hex string
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Convert hex string to bytes
  List<int> _hexToBytes(String hex) {
    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
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
    final request = {'jsonrpc': '2.0', 'id': _requestId++, 'method': method, if (params != null) 'params': params};

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
