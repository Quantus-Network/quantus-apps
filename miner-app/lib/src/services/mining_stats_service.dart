enum MiningStatus { idle, syncing, mining }

class MiningStats {
  final int peerCount;
  final int currentBlock;
  final int targetBlock;
  final double hashrate;
  final int workers;
  final int cpuCapacity;
  final int gpuDevices;
  final int gpuCapacity;
  final bool isSyncing;
  final MiningStatus status;
  final String chainName;

  MiningStats({
    required this.peerCount,
    required this.currentBlock,
    required this.targetBlock,
    required this.hashrate,
    required this.workers,
    required this.cpuCapacity,
    this.gpuDevices = 0,
    this.gpuCapacity = 0,
    required this.isSyncing,
    required this.status,
    required this.chainName,
  });

  MiningStats.empty()
    : peerCount = 0,
      currentBlock = 0,
      targetBlock = 0,
      hashrate = 0.0,
      workers = 0,
      cpuCapacity = 0,
      gpuDevices = 0,
      gpuCapacity = 0,
      isSyncing = false,
      status = MiningStatus.idle,
      chainName = '';

  MiningStats copyWith({
    int? peerCount,
    int? currentBlock,
    int? targetBlock,
    double? hashrate,
    int? workers,
    int? cpuCapacity,
    int? gpuDevices,
    int? gpuCapacity,
    bool? isSyncing,
    MiningStatus? status,
    String? chainName,
  }) {
    return MiningStats(
      peerCount: peerCount ?? this.peerCount,
      currentBlock: currentBlock ?? this.currentBlock,
      targetBlock: targetBlock ?? this.targetBlock,
      hashrate: hashrate ?? this.hashrate,
      workers: workers ?? this.workers,
      cpuCapacity: cpuCapacity ?? this.cpuCapacity,
      gpuDevices: gpuDevices ?? this.gpuDevices,
      gpuCapacity: gpuCapacity ?? this.gpuCapacity,
      isSyncing: isSyncing ?? this.isSyncing,
      status: status ?? this.status,
      chainName: chainName ?? this.chainName,
    );
  }

  @override
  String toString() {
    return 'Mining Stats - Hashrate: ${hashrate.toStringAsFixed(2)} H/s, '
        'Workers: $workers, GPUs: $gpuDevices/$gpuCapacity, Block: $currentBlock/$targetBlock, '
        'Peers: $peerCount, Chain: $chainName, Status: ${status.name}';
  }
}

/// mining_stats_service.dart
/// Service that maintains mining statistics from RPC and external miner data
class MiningStatsService {
  MiningStats _currentStats = MiningStats.empty();

  MiningStats get currentStats => _currentStats;

  /// Update peer count from RPC data
  void updatePeerCount(int peers) {
    if (_currentStats.peerCount != peers) {
      _currentStats = _currentStats.copyWith(peerCount: peers);
    }
  }

  /// Update hashrate (from HashrateEstimator)
  void updateHashrate(double hashrate) {
    if (_currentStats.hashrate != hashrate) {
      _currentStats = _currentStats.copyWith(hashrate: hashrate);
    }
  }

  /// Update workers count
  void updateWorkers(int workers) {
    if (_currentStats.workers != workers) {
      _currentStats = _currentStats.copyWith(workers: workers);
    }
  }

  /// Update CPU capacity
  void updateCpuCapacity(int cpuCapacity) {
    if (_currentStats.cpuCapacity != cpuCapacity) {
      _currentStats = _currentStats.copyWith(cpuCapacity: cpuCapacity);
    }
  }

  /// Update GPU devices count (active)
  void updateGpuDevices(int gpuDevices) {
    if (_currentStats.gpuDevices != gpuDevices) {
      _currentStats = _currentStats.copyWith(gpuDevices: gpuDevices);
    }
  }

  /// Update GPU capacity (detected total)
  void updateGpuCapacity(int gpuCapacity) {
    if (_currentStats.gpuCapacity != gpuCapacity) {
      _currentStats = _currentStats.copyWith(gpuCapacity: gpuCapacity);
    }
  }

  /// Update target block
  void updateTargetBlock(int targetBlock) {
    if (_currentStats.targetBlock != targetBlock) {
      _currentStats = _currentStats.copyWith(targetBlock: targetBlock);
    }
  }

  /// Manually set syncing state (used by RPC client)
  void setSyncingState(bool isSyncing, int? currentBlock, int? targetBlock) {
    final status = isSyncing ? MiningStatus.syncing : MiningStatus.mining;

    _currentStats = _currentStats.copyWith(
      isSyncing: isSyncing,
      status: status,
      currentBlock: currentBlock ?? _currentStats.currentBlock,
      targetBlock: targetBlock ?? _currentStats.targetBlock,
    );
  }

  /// Update chain name from RPC data
  void updateChainName(String chainName) {
    if (_currentStats.chainName != chainName) {
      _currentStats = _currentStats.copyWith(chainName: chainName);
    }
  }

  /// Reset stats to empty state
  void reset() {
    _currentStats = MiningStats.empty();
  }
}
