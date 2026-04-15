import 'dart:async';
import 'dart:io';

import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/models/miner_error.dart';
import 'package:quantus_miner/src/services/chain_rpc_client.dart';
import 'package:quantus_miner/src/services/external_miner_api_client.dart';
import 'package:quantus_miner/src/services/log_stream_processor.dart';
import 'package:quantus_miner/src/services/miner_process_manager.dart';
import 'package:quantus_miner/src/services/miner_state_service.dart';
import 'package:quantus_miner/src/services/mining_stats_service.dart';
import 'package:quantus_miner/src/services/node_process_manager.dart';
import 'package:quantus_miner/src/services/process_cleanup_service.dart';
import 'package:quantus_miner/src/services/prometheus_service.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('Orchestrator');

/// Current state of the mining orchestrator.
enum MiningState {
  /// Not started, ready to begin.
  idle,

  /// Node is starting up.
  startingNode,

  /// Node is running, waiting for RPC to be ready.
  waitingForRpc,

  /// Node is running (RPC ready), miner not started.
  nodeRunning,

  /// Miner is starting up.
  startingMiner,

  /// Both node and miner are running, mining is active.
  mining,

  /// Stopping miner only.
  stoppingMiner,

  /// Currently stopping everything.
  stopping,

  /// An error occurred.
  error,
}

/// Configuration for starting a mining session.
class MiningSessionConfig {
  /// Path to the node binary.
  final File nodeBinary;

  /// Path to the miner binary.
  final File minerBinary;

  /// Path to the node identity key file.
  final File identityFile;

  /// The rewards inner hash (hex format with 0x prefix) to pass to the node.
  /// This is the first_hash derived from the wormhole secret.
  final String rewardsInnerHash;

  /// The wormhole address (SS58) where mining rewards are sent.
  /// Used for transfer tracking.
  final String? wormholeAddress;

  /// Chain ID to connect to.
  final String chainId;

  /// Number of CPU worker threads.
  final int cpuWorkers;

  /// Number of GPU devices to use.
  final int gpuDevices;

  /// Detected GPU count for stats.
  final int detectedGpuCount;

  /// Port for QUIC miner connection.
  final int minerListenPort;

  MiningSessionConfig({
    required this.nodeBinary,
    required this.minerBinary,
    required this.identityFile,
    required this.rewardsInnerHash,
    this.wormholeAddress,
    this.chainId = 'dev',
    this.cpuWorkers = 8,
    this.gpuDevices = 0,
    this.detectedGpuCount = 0,
    this.minerListenPort = 9833,
  });
}

/// Orchestrates the complete mining workflow.
///
/// Coordinates:
/// - Node process lifecycle
/// - Miner process lifecycle
/// - Stats collection from multiple sources
/// - Error handling and crash detection
///
/// This is the main entry point for mining operations and replaces
/// the old monolithic MinerProcess class.
class MiningOrchestrator {
  // Process managers
  final NodeProcessManager _nodeManager = NodeProcessManager();
  final MinerProcessManager _minerManager = MinerProcessManager();

  // API clients for stats
  late ExternalMinerApiClient _minerApiClient;
  late PollingChainRpcClient _chainRpcClient;
  late PrometheusService _prometheusService;

  // Stats
  final MiningStatsService _statsService = MiningStatsService();

  // State
  MiningState _state = MiningState.idle;
  Timer? _prometheusTimer;
  int _actualMetricsPort = MinerConfig.defaultMinerMetricsPort;

  // Hashrate tracking for resilience
  double _lastValidHashrate = 0.0;
  int _consecutiveMetricsFailures = 0;

  // Centralized state service for balance/transfer tracking
  final MinerStateService _stateService = MinerStateService();
  int _lastTrackedBlock = 0;
  bool _isTrackingTransfers = false;

  // Stream controllers
  final _logsController = StreamController<LogEntry>.broadcast();
  final _statsController = StreamController<MiningStats>.broadcast();
  final _errorController = StreamController<MinerError>.broadcast();
  final _stateController = StreamController<MiningState>.broadcast();

  // Subscriptions
  StreamSubscription<LogEntry>? _nodeLogsSubscription;
  StreamSubscription<LogEntry>? _minerLogsSubscription;
  StreamSubscription<MinerError>? _nodeErrorSubscription;
  StreamSubscription<MinerError>? _minerErrorSubscription;

  // ============================================================
  // Public API
  // ============================================================

  /// Current mining state.
  MiningState get state => _state;

  /// Stream of log entries from both node and miner.
  Stream<LogEntry> get logsStream => _logsController.stream;

  /// Stream of mining statistics updates.
  Stream<MiningStats> get statsStream => _statsController.stream;

  /// Stream of errors (crashes, startup failures, etc.).
  Stream<MinerError> get errorStream => _errorController.stream;

  /// Stream of state changes.
  Stream<MiningState> get stateStream => _stateController.stream;

  /// Current mining statistics.
  MiningStats get currentStats => _statsService.currentStats;

  /// Whether mining is currently active.
  bool get isMining => _state == MiningState.mining;

  /// Whether the node is running (with or without miner).
  bool get isNodeRunning =>
      _state == MiningState.nodeRunning ||
      _state == MiningState.startingMiner ||
      _state == MiningState.mining ||
      _state == MiningState.stoppingMiner;

  /// Whether the orchestrator is in any running state.
  bool get isRunning => _state != MiningState.idle && _state != MiningState.error;

  /// Node process PID, if running.
  int? get nodeProcessPid => _nodeManager.pid;

  /// Miner process PID, if running.
  int? get minerProcessPid => _minerManager.pid;

  // Store config for later use when starting miner separately
  MiningSessionConfig? _currentConfig;

  MiningOrchestrator() {
    _initializeApiClients();
    _setupNodeSyncCallback();
    _subscribeToProcessEvents();
  }

  /// Start mining with the given configuration (starts both node and miner).
  ///
  /// This will:
  /// 1. Cleanup any existing processes
  /// 2. Ensure ports are available
  /// 3. Start the node and wait for RPC
  /// 4. Start the miner
  /// 5. Begin polling for stats
  Future<void> start(MiningSessionConfig config) async {
    await startNode(config);
    if (_state == MiningState.nodeRunning) {
      await startMiner();
    }
  }

  /// Start only the node (without the miner).
  ///
  /// Use this to enable balance queries and chain sync without mining.
  Future<void> startNode(MiningSessionConfig config) async {
    if (_state != MiningState.idle && _state != MiningState.error) {
      _log.w('Cannot start node: already in state $_state');
      return;
    }

    _currentConfig = config;

    try {
      // Initialize stats with worker counts
      _statsService.updateWorkers(config.cpuWorkers);
      _statsService.updateCpuCapacity(Platform.numberOfProcessors);
      _statsService.updateGpuDevices(config.gpuDevices);
      _statsService.updateGpuCapacity(config.detectedGpuCount);
      _emitStats();

      // Perform pre-start cleanup
      _setState(MiningState.startingNode);
      await ProcessCleanupService.performPreStartCleanup(config.chainId);

      // Ensure ports are available
      final ports = await ProcessCleanupService.ensurePortsAvailable(
        quicPort: config.minerListenPort,
        metricsPort: MinerConfig.defaultMinerMetricsPort,
      );
      _actualMetricsPort = ports['metrics']!;
      _updateMetricsClient();

      // Start node with rewards inner hash directly from config
      await _nodeManager.start(
        NodeConfig(
          binary: config.nodeBinary,
          identityFile: config.identityFile,
          rewardsInnerHash: config.rewardsInnerHash,
          chainId: config.chainId,
          minerListenPort: config.minerListenPort,
        ),
      );

      // Wait for node RPC to be ready
      _setState(MiningState.waitingForRpc);
      await _waitForNodeRpc();

      // Start chain RPC polling (for balance, sync status, etc.)
      _chainRpcClient.startPolling();

      // Start Prometheus polling for target block
      _prometheusTimer?.cancel();
      _prometheusTimer = Timer.periodic(MinerConfig.prometheusPollingInterval, (_) => _fetchPrometheusMetrics());

      // Initialize centralized state service (handles transfer tracking, balance, etc.)
      await _stateService.startSession(rpcUrl: MinerConfig.nodeRpcUrl(MinerConfig.defaultNodeRpcPort));
      _log.i('Miner state service session started');

      _setState(MiningState.nodeRunning);
      _log.i('Node started successfully');
    } catch (e, st) {
      _log.e('Failed to start node', error: e, stackTrace: st);
      _setState(MiningState.error);
      await _stopInternal();
      rethrow;
    }
  }

  /// Update miner settings (CPU workers, GPU devices).
  /// Call this before startMiner() if settings have changed.
  void updateMinerSettings({int? cpuWorkers, int? gpuDevices}) {
    if (_currentConfig == null) {
      _log.w('Cannot update settings: no config available');
      return;
    }

    _currentConfig = MiningSessionConfig(
      nodeBinary: _currentConfig!.nodeBinary,
      minerBinary: _currentConfig!.minerBinary,
      identityFile: _currentConfig!.identityFile,
      rewardsInnerHash: _currentConfig!.rewardsInnerHash,
      chainId: _currentConfig!.chainId,
      cpuWorkers: cpuWorkers ?? _currentConfig!.cpuWorkers,
      gpuDevices: gpuDevices ?? _currentConfig!.gpuDevices,
      detectedGpuCount: _currentConfig!.detectedGpuCount,
      minerListenPort: _currentConfig!.minerListenPort,
    );

    // Update stats to reflect new settings
    _statsService.updateWorkers(_currentConfig!.cpuWorkers);
    _statsService.updateGpuDevices(_currentConfig!.gpuDevices);
    _emitStats();

    _log.i(
      'Miner settings updated: cpuWorkers=${_currentConfig!.cpuWorkers}, gpuDevices=${_currentConfig!.gpuDevices}',
    );
  }

  /// Start the miner (node must already be running).
  Future<void> startMiner() async {
    if (_state != MiningState.nodeRunning) {
      _log.w('Cannot start miner: node not running (state: $_state)');
      return;
    }

    if (_currentConfig == null) {
      _log.e('Cannot start miner: no config available');
      return;
    }

    final config = _currentConfig!;

    try {
      _setState(MiningState.startingMiner);

      await _minerManager.start(
        ExternalMinerConfig(
          binary: config.minerBinary,
          nodeAddress: '${MinerConfig.localhost}:${config.minerListenPort}',
          cpuWorkers: config.cpuWorkers,
          gpuDevices: config.gpuDevices,
          metricsPort: _actualMetricsPort,
        ),
      );

      // Start miner metrics polling
      _minerApiClient.startPolling();

      // Update stats to reflect miner is running
      _statsService.setMinerRunning(true);
      _emitStats();

      _setState(MiningState.mining);
      _log.i('Miner started successfully');
    } catch (e, st) {
      _log.e('Failed to start miner', error: e, stackTrace: st);
      _statsService.setMinerRunning(false);
      _setState(MiningState.nodeRunning); // Revert to node-only state
      rethrow;
    }
  }

  /// Stop only the miner (keep node running).
  Future<void> stopMiner() async {
    if (_state != MiningState.mining) {
      _log.w('Cannot stop miner: not mining (state: $_state)');
      return;
    }

    _log.i('Stopping miner...');
    _setState(MiningState.stoppingMiner);

    _minerApiClient.stopPolling();
    await _minerManager.stop();

    // Update stats to reflect miner is stopped
    _statsService.setMinerRunning(false);
    _resetStats();
    _setState(MiningState.nodeRunning);
    _log.i('Miner stopped, node still running');
  }

  /// Stop everything (node and miner) gracefully.
  Future<void> stop() async {
    if (_state == MiningState.idle) {
      return;
    }

    _log.i('Stopping everything...');
    _setState(MiningState.stopping);
    await _stopInternal();
    _setState(MiningState.idle);
    _resetStats();
    _currentConfig = null;
    _log.i('All processes stopped');
  }

  /// Stop only the node (and miner if running).
  Future<void> stopNode() async {
    if (!isNodeRunning && _state != MiningState.startingNode && _state != MiningState.waitingForRpc) {
      _log.w('Cannot stop node: not running (state: $_state)');
      return;
    }

    _log.i('Stopping node...');
    _setState(MiningState.stopping);
    await _stopInternal();
    _setState(MiningState.idle);
    _resetStats();
    _currentConfig = null;
    _log.i('Node stopped');
  }

  /// Force stop everything immediately.
  void forceStop() {
    _log.i('Force stopping everything...');
    _setState(MiningState.stopping);

    _stopPolling();
    _minerManager.forceStop();
    _nodeManager.forceStop();

    _setState(MiningState.idle);
    _resetStats();
    _currentConfig = null;
    _log.i('Force stopped');
  }

  /// Dispose of all resources.
  void dispose() {
    forceStop();

    _nodeLogsSubscription?.cancel();
    _minerLogsSubscription?.cancel();
    _nodeErrorSubscription?.cancel();
    _minerErrorSubscription?.cancel();

    _nodeManager.dispose();
    _minerManager.dispose();
    _minerApiClient.dispose();
    _chainRpcClient.dispose();

    _logsController.close();
    _statsController.close();
    _errorController.close();
    _stateController.close();
  }

  // ============================================================
  // Internal Implementation
  // ============================================================

  void _initializeApiClients() {
    _minerApiClient = ExternalMinerApiClient(
      metricsUrl: MinerConfig.minerMetricsUrl(MinerConfig.defaultMinerMetricsPort),
    );
    _minerApiClient.onMetricsUpdate = _handleMinerMetrics;
    _minerApiClient.onError = _handleMinerMetricsError;

    _chainRpcClient = PollingChainRpcClient();
    _chainRpcClient.onChainInfoUpdate = _handleChainInfo;
    _chainRpcClient.onError = _handleChainRpcError;

    _prometheusService = PrometheusService();
  }

  void _setupNodeSyncCallback() {
    _nodeManager.getSyncState = () => _statsService.currentStats.isSyncing;
  }

  void _subscribeToProcessEvents() {
    // Forward node logs
    _nodeLogsSubscription = _nodeManager.logs.listen((entry) {
      _logsController.add(entry);
    });

    // Forward miner logs
    _minerLogsSubscription = _minerManager.logs.listen((entry) {
      _logsController.add(entry);
    });

    // Forward node errors
    _nodeErrorSubscription = _nodeManager.errors.listen((error) {
      _errorController.add(error);
      if (error.type == MinerErrorType.nodeCrashed && _state == MiningState.mining) {
        _log.w('Node crashed while mining, stopping...');
        _handleCrash();
      }
    });

    // Forward miner errors
    _minerErrorSubscription = _minerManager.errors.listen((error) {
      _errorController.add(error);
      if (error.type == MinerErrorType.minerCrashed && _state == MiningState.mining) {
        _log.w('Miner crashed while mining');
        // Don't stop everything - just emit the error for UI to show
      }
    });
  }

  void _updateMetricsClient() {
    if (_actualMetricsPort != MinerConfig.defaultMinerMetricsPort) {
      _minerApiClient = ExternalMinerApiClient(metricsUrl: MinerConfig.minerMetricsUrl(_actualMetricsPort));
      _minerApiClient.onMetricsUpdate = _handleMinerMetrics;
      _minerApiClient.onError = _handleMinerMetricsError;
    }
  }

  Future<void> _waitForNodeRpc() async {
    _log.d('Waiting for node RPC...');
    int attempts = 0;
    Duration delay = MinerConfig.rpcInitialRetryDelay;

    while (attempts < MinerConfig.maxRpcRetries) {
      try {
        final isReady = await _chainRpcClient.isReachable();
        if (isReady) {
          _log.i('Node RPC is ready');
          return;
        }
      } catch (e) {
        // Expected during startup
      }

      attempts++;
      _log.d('RPC not ready (attempt $attempts/${MinerConfig.maxRpcRetries})');
      await Future.delayed(delay);

      if (delay < MinerConfig.rpcMaxRetryDelay) {
        delay = Duration(seconds: (delay.inSeconds * 1.5).round());
        if (delay > MinerConfig.rpcMaxRetryDelay) {
          delay = MinerConfig.rpcMaxRetryDelay;
        }
      }
    }

    _log.w('Node RPC not ready after max attempts, proceeding anyway');
  }

  void _stopPolling() {
    _minerApiClient.stopPolling();
    _chainRpcClient.stopPolling();
    _prometheusTimer?.cancel();
    _prometheusTimer = null;
  }

  Future<void> _stopInternal() async {
    _stopPolling();

    // Stop miner first (depends on node)
    await _minerManager.stop();

    // Then stop node
    await _nodeManager.stop();

    // Stop state service session (clears transfers, resets balance)
    await _stateService.stopSession();

    // Reset local tracking state
    _lastTrackedBlock = 0;
    _isTrackingTransfers = false;
  }

  void _handleCrash() {
    _setState(MiningState.error);
    _stopPolling();
  }

  void _setState(MiningState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      _log.d('State changed to: $newState');
    }
  }

  void _emitStats() {
    _statsController.add(_statsService.currentStats);
  }

  void _resetStats() {
    _statsService.updateHashrate(0);
    _statsService.setMinerRunning(false);
    _lastValidHashrate = 0;
    _consecutiveMetricsFailures = 0;
    _emitStats();
  }

  // ============================================================
  // Metrics Handlers
  // ============================================================

  void _handleMinerMetrics(ExternalMinerMetrics metrics) {
    if (metrics.isHealthy && metrics.hashRate > 0) {
      _lastValidHashrate = metrics.hashRate;
      _consecutiveMetricsFailures = 0;

      _statsService.updateHashrate(metrics.hashRate);
      // NOTE: Don't update workers from metrics - miner_workers includes GPU workers
      // which would incorrectly inflate the CPU count. We use the configured cpuWorkers instead.
      if (metrics.cpuCapacity > 0) {
        _statsService.updateCpuCapacity(metrics.cpuCapacity);
      }
      // NOTE: Don't update gpuDevices from metrics - use the configured value instead
      // if (metrics.gpuDevices > 0) {
      //   _statsService.updateGpuDevices(metrics.gpuDevices);
      // }
      _emitStats();
    } else if (metrics.hashRate == 0.0 && _lastValidHashrate > 0) {
      // Keep last valid hashrate during temporary zeroes
      _statsService.updateHashrate(_lastValidHashrate);
      _emitStats();
    } else {
      _consecutiveMetricsFailures++;
      if (_consecutiveMetricsFailures >= MinerConfig.maxConsecutiveMetricsFailures) {
        _statsService.updateHashrate(0);
        _lastValidHashrate = 0;
        _emitStats();
      } else if (_lastValidHashrate > 0) {
        _statsService.updateHashrate(_lastValidHashrate);
        _emitStats();
      }
    }
  }

  void _handleMinerMetricsError(String error) {
    _consecutiveMetricsFailures++;
    if (_consecutiveMetricsFailures >= MinerConfig.maxConsecutiveMetricsFailures) {
      if (_statsService.currentStats.hashrate != 0) {
        _statsService.updateHashrate(0);
        _lastValidHashrate = 0;
        _emitStats();
      }
    }
  }

  void _handleChainInfo(ChainInfo info) {
    if (info.peerCount >= 0) {
      _statsService.updatePeerCount(info.peerCount);
    }
    _statsService.updateChainName(info.chainName);
    _statsService.setSyncingState(info.isSyncing, info.currentBlock, info.targetBlock ?? info.currentBlock);
    _emitStats();

    // Track transfers when new blocks are detected (for withdrawal proofs)
    // Detect chain reset (dev chain restart) - current block is less than last tracked
    if (info.currentBlock < _lastTrackedBlock && _lastTrackedBlock > 0) {
      _log.i('Chain reset detected (block ${info.currentBlock} < $_lastTrackedBlock), resetting state');
      _lastTrackedBlock = 0;
      _stateService.onChainReset();
    }

    // Initialize _lastTrackedBlock on first chain info to avoid processing old blocks
    if (_lastTrackedBlock == 0 && info.currentBlock > 0) {
      _lastTrackedBlock = info.currentBlock;
      _log.i('Initialized transfer tracking at block $_lastTrackedBlock');
    } else if (info.currentBlock > _lastTrackedBlock && _state == MiningState.mining && !_isTrackingTransfers) {
      _trackNewBlockTransfers(info.currentBlock);
    }

    // Always update block number in state service (for UI updates)
    _stateService.updateBlockNumber(info.currentBlock);
  }

  /// Track transfers in newly detected blocks for withdrawal proof generation.
  ///
  /// Processes blocks sequentially to avoid race conditions in MinerStateService.
  Future<void> _trackNewBlockTransfers(int currentBlock) async {
    if (_isTrackingTransfers) return; // Prevent overlapping calls
    _isTrackingTransfers = true;

    try {
      // Process all blocks since last tracked (in case we missed some)
      for (int block = _lastTrackedBlock + 1; block <= currentBlock; block++) {
        await _getBlockHashAndTrack(block);
      }
      _lastTrackedBlock = currentBlock;
    } finally {
      _isTrackingTransfers = false;
    }
  }

  /// Get block hash and process for transfer tracking via MinerStateService.
  Future<void> _getBlockHashAndTrack(int blockNumber) async {
    try {
      // Get block hash from block number
      final blockHash = await _chainRpcClient.getBlockHash(blockNumber);
      if (blockHash != null) {
        await _stateService.onBlockMined(blockNumber, blockHash);
      }
    } catch (e) {
      _log.w('Failed to track transfers for block $blockNumber: $e');
    }
  }

  void _handleChainRpcError(String error) {
    if (!error.contains('Connection refused') && !error.contains('timeout')) {
      _log.w('Chain RPC error: $error');
    }
  }

  Future<void> _fetchPrometheusMetrics() async {
    try {
      final metrics = await _prometheusService.fetchMetrics();
      if (metrics?.targetBlock != null) {
        if (_statsService.currentStats.targetBlock < metrics!.targetBlock!) {
          _statsService.updateTargetBlock(metrics.targetBlock!);
          _emitStats();
        }
      }
    } catch (e) {
      _log.w('Failed to fetch Prometheus metrics', error: e);
    }
  }
}
