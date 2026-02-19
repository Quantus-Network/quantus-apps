import 'dart:io';

import 'package:quantus_miner/src/models/miner_error.dart';
import 'package:quantus_miner/src/services/base_process_manager.dart';
import 'package:quantus_miner/src/services/process_cleanup_service.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('ExternalMiner');

/// Configuration for starting the external miner process.
class ExternalMinerConfig {
  /// Path to the miner binary.
  final File binary;

  /// Address and port of the node's QUIC endpoint (e.g., "127.0.0.1:9833").
  final String nodeAddress;

  /// Number of CPU worker threads.
  final int cpuWorkers;

  /// Number of GPU devices to use.
  final int gpuDevices;

  /// Port for the miner's Prometheus metrics endpoint.
  final int metricsPort;

  ExternalMinerConfig({
    required this.binary,
    required this.nodeAddress,
    this.cpuWorkers = 8,
    this.gpuDevices = 0,
    this.metricsPort = 9900,
  });
}

/// Manages the quantus-miner (external miner) process lifecycle.
///
/// Responsibilities:
/// - Starting the miner process with proper arguments
/// - Monitoring process health and exit
/// - Stopping the process gracefully or forcefully
/// - Emitting log entries and error events
class MinerProcessManager extends BaseProcessManager {
  @override
  TaggedLoggerWrapper get log => _log;

  @override
  String get processName => 'miner';

  @override
  MinerError createStartupError(dynamic error, [StackTrace? stackTrace]) {
    return MinerError.minerStartupFailed(error, stackTrace);
  }

  @override
  MinerError createCrashError(int exitCode) {
    return MinerError.minerCrashed(exitCode);
  }

  MinerProcessManager() {
    initLogProcessor('miner');
  }

  /// Start the miner process.
  ///
  /// Throws an exception if startup fails.
  Future<void> start(ExternalMinerConfig config) async {
    if (isRunning) {
      log.w('Miner already running (PID: $pid)');
      return;
    }

    intentionalStop = false;

    // Validate binary exists
    if (!await config.binary.exists()) {
      final error = MinerError.minerStartupFailed('Miner binary not found: ${config.binary.path}');
      errorController.add(error);
      throw Exception(error.message);
    }

    // Build command arguments
    final args = _buildArgs(config);

    log.i('Starting miner...');
    log.d('Command: ${config.binary.path} ${args.join(' ')}');

    try {
      final proc = await Process.start(config.binary.path, args);
      attachProcess(proc);

      // Monitor for unexpected exit
      proc.exitCode.then(handleExit);

      // Verify it started successfully by waiting briefly
      await Future.delayed(const Duration(seconds: 2));

      // Check if process is still running
      // We just attached, so pid should be available
      final processPid = pid;
      if (processPid != null) {
        final stillRunning = await ProcessCleanupService.isProcessRunning(processPid);
        if (!stillRunning) {
          final error = MinerError.minerStartupFailed('Miner died during startup');
          errorController.add(error);
          clearProcess();
          throw Exception(error.message);
        }
      }

      log.i('Miner started (PID: $pid)');
    } catch (e, st) {
      if (e.toString().contains('Miner died during startup')) {
        rethrow;
      }
      final error = MinerError.minerStartupFailed(e, st);
      errorController.add(error);
      clearProcess();
      rethrow;
    }
  }

  List<String> _buildArgs(ExternalMinerConfig config) {
    return [
      'serve', // Subcommand required by new miner CLI
      '--node-addr',
      config.nodeAddress,
      '--cpu-workers',
      config.cpuWorkers.toString(),
      '--gpu-devices',
      config.gpuDevices.toString(),
      '--metrics-port',
      config.metricsPort.toString(),
    ];
  }
}
