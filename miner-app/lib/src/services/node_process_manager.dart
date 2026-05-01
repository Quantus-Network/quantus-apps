import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/models/miner_error.dart';
import 'package:quantus_miner/src/services/base_process_manager.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/services/log_stream_processor.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('NodeProcess');

/// Configuration for starting the node process.
class NodeConfig {
  /// Path to the node binary.
  final File binary;

  /// Path to the node identity key file.
  final File identityFile;

  /// The rewards inner hash (first hash) for mining rewards.
  /// This is passed to the node via --rewards-inner-hash flag.
  /// Must be hex-encoded with 0x prefix.
  final String rewardsInnerHash;

  /// Chain ID to connect to ('dev' or 'dirac').
  final String chainId;

  /// Port for the QUIC miner connection.
  final int minerListenPort;

  /// Port for JSON-RPC endpoint.
  final int rpcPort;

  /// Port for Prometheus metrics.
  final int prometheusPort;

  /// Port for P2P networking.
  final int p2pPort;

  NodeConfig({
    required this.binary,
    required this.identityFile,
    required this.rewardsInnerHash,
    this.chainId = 'dev',
    this.minerListenPort = 9833,
    this.rpcPort = 9933,
    this.prometheusPort = 9616,
    this.p2pPort = 30333,
  });
}

/// Manages the quantus-node process lifecycle.
///
/// Responsibilities:
/// - Starting the node process with proper arguments
/// - Monitoring process health and exit
/// - Stopping the process gracefully or forcefully
/// - Emitting log entries and error events
class NodeProcessManager extends BaseProcessManager {
  /// Callback to get current sync state for log filtering.
  SyncStateProvider? getSyncState;

  @override
  TaggedLoggerWrapper get log => _log;

  @override
  String get processName => 'node';

  @override
  MinerError createStartupError(dynamic error, [StackTrace? stackTrace]) {
    return MinerError.nodeStartupFailed(error, stackTrace);
  }

  @override
  MinerError createCrashError(int exitCode) {
    return MinerError.nodeCrashed(exitCode);
  }

  NodeProcessManager() {
    initLogProcessor('node', getSyncState: () => getSyncState?.call() ?? false);
  }

  /// Start the node process.
  ///
  /// Throws an exception if startup fails.
  Future<void> start(NodeConfig config) async {
    if (isRunning) {
      log.w('Node already running (PID: $pid)');
      return;
    }

    intentionalStop = false;

    // Validate binary exists
    if (!await config.binary.exists()) {
      final error = MinerError.nodeStartupFailed('Node binary not found: ${config.binary.path}');
      errorController.add(error);
      throw Exception(error.message);
    }

    // Validate identity file exists
    if (!await config.identityFile.exists()) {
      final error = MinerError.nodeStartupFailed('Identity file not found: ${config.identityFile.path}');
      errorController.add(error);
      throw Exception(error.message);
    }

    // Prepare data directory
    final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
    final basePath = p.join(quantusHome, 'node_data');
    await Directory(basePath).create(recursive: true);

    // Build command arguments
    final args = _buildArgs(config, basePath);

    log.i('Starting node...');
    log.d('Command: ${config.binary.path} ${args.join(' ')}');

    try {
      final proc = await Process.start(config.binary.path, args);
      attachProcess(proc);

      // Monitor for unexpected exit
      proc.exitCode.then(handleExit);

      log.i('Node started (PID: $pid)');
    } catch (e, st) {
      final error = MinerError.nodeStartupFailed(e, st);
      errorController.add(error);
      clearProcess();
      rethrow;
    }
  }

  List<String> _buildArgs(NodeConfig config, String basePath) {
    return [
      // Only use --base-path for non-dev chains (dev uses temp storage for fresh state)
      if (config.chainId != 'dev') ...['--base-path', basePath],
      '--node-key-file', config.identityFile.path,
      '--rewards-inner-hash', config.rewardsInnerHash,
      '--validator',
      // Chain selection
      if (config.chainId == 'dev') '--dev' else ...['--chain', config.chainId],
      '--port', config.p2pPort.toString(),
      '--no-mdns',
      '--prometheus-port', config.prometheusPort.toString(),
      '--experimental-rpc-endpoint',
      'listen-addr=${MinerConfig.localhost}:${config.rpcPort},methods=unsafe,cors=all',
      '--name', 'QuantusMinerGUI',
      '--miner-listen-port', config.minerListenPort.toString(),
      '--enable-peer-sharing',
    ];
  }
}
