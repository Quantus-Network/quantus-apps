import 'dart:async';

import 'package:quantus_sdk/quantus_sdk.dart';

import 'miner_process.dart';

class MiningStats {
  final int peerCount;
  final int currentBlock;
  final int targetBlock;
  final double hashrate;
  final bool isSyncing;
  final String status;

  MiningStats({
    required this.peerCount,
    required this.currentBlock,
    required this.targetBlock,
    required this.hashrate,
    required this.isSyncing,
    required this.status,
  });

  @override
  String toString() {
    return 'Peers: $peerCount | Block: $currentBlock/$targetBlock | Hashrate: ${hashrate.toStringAsFixed(2)} H/s | Status: $status';
  }
}

class MiningStatsService {
  final SubstrateService _substrateService = SubstrateService();
  Timer? _statsTimer;
  MiningStats? _lastStats;
  MinerProcess? _minerProcess; // Reference to miner process for hashrate

  final _statsController = StreamController<MiningStats>.broadcast();
  Stream<MiningStats> get statsStream => _statsController.stream;

  MiningStats? get lastStats => _lastStats;

  void setMinerProcess(MinerProcess? minerProcess) {
    _minerProcess = minerProcess;
  }

  Future<void> startMonitoring() async {
    // Initialize the SubstrateService first
    try {
      await _substrateService.initialize();
      print('MiningStatsService: Initialized Substrate service');
    } catch (e) {
      print('MiningStatsService: Failed to initialize Substrate service: $e');
      return; // Don't start monitoring if initialization fails
    }

    // Start periodic stats fetching
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchStats();
    });

    // Fetch initial stats
    await _fetchStats();
  }

  Future<void> stopMonitoring() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    _statsController.close();
  }

  Future<void> _fetchStats() async {
    try {
      final peerCount = await _getPeerCount();
      final currentBlock = await _getCurrentBlock();
      final targetBlock = await _getTargetBlock();
      final hashrate = await _getHashrate();
      final isSyncing = await _getSyncStatus();

      String status = 'Unknown';
      if (isSyncing) {
        status = 'Syncing';
      } else if (hashrate > 0) {
        status = 'Mining';
      } else {
        status = 'Idle';
      }

      final stats = MiningStats(
        peerCount: peerCount,
        currentBlock: currentBlock,
        targetBlock: targetBlock,
        hashrate: hashrate,
        isSyncing: isSyncing,
        status: status,
      );

      _lastStats = stats;
      _statsController.add(stats);
    } catch (e) {
      print('Error fetching mining stats: $e');
      // Don't add to stream on error, keep last known stats
    }
  }

  Future<int> _getPeerCount() async {
    try {
      if (_substrateService.provider == null) {
        print('Provider not available for peer count');
        return 0;
      }
      final result = await _substrateService.provider!.send('system_peers', []);
      if (result.result == null) {
        print('Peer count result is null');
        return 0;
      }
      final peers = result.result as List;
      return peers.length;
    } catch (e) {
      print('Error getting peer count: $e');
      return 0;
    }
  }

  Future<int> _getCurrentBlock() async {
    try {
      if (_substrateService.provider == null) {
        print('Provider not available for current block');
        return 0;
      }
      final result = await _substrateService.provider!.send(
        'chain_getHeader',
        [],
      );
      final blockNumber = result.result['number'];
      if (blockNumber is String) {
        return int.parse(blockNumber);
      } else if (blockNumber is int) {
        return blockNumber;
      }
      return 0;
    } catch (e) {
      print('Error getting current block: $e');
      return 0;
    }
  }

  Future<int> _getTargetBlock() async {
    try {
      // For now, just return current block + 1 as target
      // This could be improved by getting the actual target from the node
      final currentBlock = await _getCurrentBlock();
      return currentBlock + 1;
    } catch (e) {
      print('Error getting target block: $e');
      return 0;
    }
  }

  Future<double> _getHashrate() async {
    // Get hashrate from MinerProcess if available
    if (_minerProcess != null) {
      return _minerProcess!.currentHashrate ?? 0.0;
    }
    return 0.0;
  }

  Future<bool> _getSyncStatus() async {
    try {
      if (_substrateService.provider == null) {
        print('Provider not available for sync status');
        return false;
      }
      final result = await _substrateService.provider!.send(
        'system_syncState',
        [],
      );
      final syncState = result.result as Map;
      final currentBlock = syncState['currentBlock'] ?? 0;
      final highestBlock = syncState['highestBlock'] ?? 0;

      // Consider syncing if we're more than 10 blocks behind
      return highestBlock - currentBlock > 10;
    } catch (e) {
      print('Error getting sync status: $e');
      return false;
    }
  }

  void dispose() {
    _statsTimer?.cancel();
    _statsController.close();
  }
}
