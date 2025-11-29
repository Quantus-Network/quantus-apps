import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quantus_miner/src/services/prometheus_service.dart';
import 'package:quantus_miner/src/shared/extensions/log_string_extension.dart';
import './mining_stats_service.dart';
import './external_miner_api_client.dart';
import './chain_rpc_client.dart';

import './binary_manager.dart';
import './log_filter_service.dart';

class LogEntry {
  final String message;
  final DateTime timestamp;
  final String source; // 'node', 'quantus-miner', 'error'

  LogEntry({required this.message, required this.timestamp, required this.source});

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String().substring(11, 19); // HH:MM:SS
    return '[$timeStr] [$source] $message';
  }
}

/// quantus_sdk/lib/src/services/miner_process.dart
class MinerProcess {
  final File bin;
  final File identityPath;
  final File rewardsPath;
  late Process _nodeProcess;
  Process? _externalMinerProcess;
  late LogFilterService _stdoutFilter;
  late LogFilterService _stderrFilter;

  late MiningStatsService _statsService;
  late PrometheusService _prometheusService;
  late ExternalMinerApiClient _externalMinerApiClient;
  late PollingChainRpcClient _chainRpcClient;

  Timer? _syncStatusTimer;
  final int minerCores;

  final int externalMinerPort;

  // Track metrics state to prevent premature hashrate reset
  double _lastValidHashrate = 0.0;
  int _consecutiveMetricsFailures = 0;
  static const int _maxConsecutiveFailures = 5;

  // Public getters for process PIDs (for cleanup tracking)
  int? get nodeProcessPid {
    try {
      return _nodeProcess.pid;
    } catch (e) {
      return null;
    }
  }

  int? get externalMinerProcessPid {
    try {
      return _externalMinerProcess?.pid;
    } catch (e) {
      return null;
    }
  }

  // Stream for logs
  final _logsController = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get logsStream => _logsController.stream;

  final Function(MiningStats stats)? onStatsUpdate;

  MinerProcess(
    this.bin,
    this.identityPath,
    this.rewardsPath, {
    this.onStatsUpdate,
    this.minerCores = 8,
    this.externalMinerPort = 9833,
  }) {
    // Initialize services
    _statsService = MiningStatsService();
    _prometheusService = PrometheusService();
    _stdoutFilter = LogFilterService();
    _stderrFilter = LogFilterService();

    // Initialize external miner API client with metrics endpoint
    _externalMinerApiClient = ExternalMinerApiClient(
      baseUrl: 'http://127.0.0.1:$externalMinerPort',
      metricsUrl: 'http://127.0.0.1:9900/metrics', // Standard metrics port
    );

    // Set up external miner API callbacks
    _externalMinerApiClient.onMetricsUpdate = _handleExternalMinerMetrics;
    _externalMinerApiClient.onError = _handleExternalMinerError;

    // Initialize chain RPC client
    _chainRpcClient = PollingChainRpcClient(rpcUrl: 'http://127.0.0.1:9933');
    _chainRpcClient.onChainInfoUpdate = _handleChainInfoUpdate;
    _chainRpcClient.onError = _handleChainRpcError;

    // Initialize stats with the configured worker count
    _statsService.updateWorkers(minerCores);
  }

  Future<void> start() async {
    // First, ensure both binaries are available
    await BinaryManager.ensureNodeBinary();

    // Cleanup any existing processes first
    await _cleanupExistingNodeProcesses();
    await _cleanupExistingMinerProcesses();

    // Cleanup database lock files if needed
    await _cleanupDatabaseLocks();

    // Ensure database directory has proper access
    await _ensureDatabaseDirectoryAccess();

    // Check if ports are available and cleanup if needed
    await _ensurePortsAvailable();

    final externalMinerBinPath = await BinaryManager.getExternalMinerBinaryFilePath();

    await BinaryManager.ensureExternalMinerBinary();
    final externalMinerBin = File(externalMinerBinPath);

    if (!await externalMinerBin.exists()) {
      throw Exception('External miner binary not found at $externalMinerBinPath');
    }

    // Start the external miner first with metrics enabled

    try {
      _externalMinerProcess = await Process.start(externalMinerBin.path, [
        '--port',
        externalMinerPort.toString(),
        '--workers',
        minerCores.toString(),
        '--metrics-port',
        await _getMetricsPort().then((port) => port.toString()),
      ]);
    } catch (e) {
      throw Exception('Failed to start external miner: $e');
    }

    // Set up external miner log handling
    _externalMinerProcess!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      final logEntry = LogEntry(message: line, timestamp: DateTime.now(), source: 'quantus-miner');
      _logsController.add(logEntry);
      print('[ext-miner] $line');
    });

    _externalMinerProcess!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      final logEntry = LogEntry(
        message: line,
        timestamp: DateTime.now(),
        source: line.isMinerError ? 'quantus-miner-error' : 'quantus-miner',
      );
      _logsController.add(logEntry);
      print('[ext-miner-err] $line');
    });

    // Monitor external miner process exit
    _externalMinerProcess!.exitCode.then((exitCode) {
      if (exitCode != 0) {
        print('External miner process exited with code: $exitCode');
      }
    });

    // Give the external miner a moment to start up
    await Future.delayed(const Duration(seconds: 3));

    // Check if external miner process is still alive
    bool minerStillRunning = true;
    try {
      // Check if the process has exited by looking at its PID
      final pid = _externalMinerProcess!.pid;
      minerStillRunning = await _isProcessRunning(pid);
    } catch (e) {
      minerStillRunning = false;
    }

    if (!minerStillRunning) {
      throw Exception('External miner process died during startup');
    }

    // Test if external miner is responding on the port
    try {
      final testClient = HttpClient();
      testClient.connectionTimeout = const Duration(seconds: 5);
      final request = await testClient.getUrl(Uri.parse('http://127.0.0.1:$externalMinerPort'));
      final response = await request.close();
      await response.drain(); // Consume the response
      testClient.close();
    } catch (e) {
      // External miner might still be starting up
    }

    // Now start the node process
    final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
    final basePath = p.join(quantusHome, 'node_data');
    await Directory(basePath).create(recursive: true);

    final nodeKeyFileFromFileSystem = await BinaryManager.getNodeKeyFile();
    if (await nodeKeyFileFromFileSystem.exists()) {
      final stat = await nodeKeyFileFromFileSystem.stat();
      print('DEBUG: nodeKeyFileFromFileSystem (${nodeKeyFileFromFileSystem.path}) exists (size: ${stat.size} bytes)');
    } else {
      print('DEBUG: nodeKeyFileFromFileSystem (${nodeKeyFileFromFileSystem.path}) does not exist.');
    }

    if (!await identityPath.exists()) {
      throw Exception('Identity file not found: ${identityPath.path}');
    }

    // Read the rewards address from the file
    String rewardsAddress;
    try {
      if (!await rewardsPath.exists()) {
        throw Exception('Rewards address file not found: ${rewardsPath.path}');
      }
      rewardsAddress = await rewardsPath.readAsString();
      rewardsAddress = rewardsAddress.trim(); // Remove any whitespace/newlines
      print('DEBUG: Read rewards address from file: $rewardsAddress');
    } catch (e) {
      throw Exception('Failed to read rewards address from file ${rewardsPath.path}: $e');
    }

    final List<String> args = [
      '--base-path',
      basePath,
      '--node-key-file',
      identityPath.path,
      '--rewards-address',
      rewardsAddress,
      '--validator',
      '--chain',
      'dirac',
      '--port',
      '30333',
      '--prometheus-port',
      '9616',
      '--experimental-rpc-endpoint',
      'listen-addr=127.0.0.1:9933,methods=unsafe,cors=all',
      '--name',
      'QuantusMinerGUI',
      '--external-miner-url',
      'http://127.0.0.1:$externalMinerPort',
      '--enable-peer-sharing',
    ];

    print('DEBUG: Executing command:\n ${bin.path} ${args.join(' ')}');
    print('DEBUG: Args: ${args.join('\n')}');

    _nodeProcess = await Process.start(bin.path, args);
    _stdoutFilter = LogFilterService();
    _stderrFilter = LogFilterService();
    // Services are now initialized in constructor

    _stdoutFilter.reset();
    _stderrFilter.reset();

    Future<void> syncBlockTargetWithPrometheusMetrics() async {
      try {
        final metrics = await _prometheusService.fetchMetrics();
        if (metrics == null || metrics.targetBlock == null) return;
        if (_statsService.currentStats.targetBlock >= metrics.targetBlock!) {
          return;
        }

        _statsService.updateTargetBlock(metrics.targetBlock!);

        onStatsUpdate?.call(_statsService.currentStats);
      } catch (e) {
        print('Failed to fetch target block height: $e');
      }
    }

    // Start Prometheus polling for target block (every 3 seconds)
    _syncStatusTimer?.cancel();
    _syncStatusTimer = Timer.periodic(const Duration(seconds: 3), (timer) => syncBlockTargetWithPrometheusMetrics());

    // Start external miner API polling (every second)
    _externalMinerApiClient.startPolling();

    // Wait for node to be ready before starting RPC polling
    _waitForNodeReadyThenStartRpc();

    // Process each log line
    void processLogLine(String line, String streamType) {
      bool shouldPrint;
      if (streamType == 'stdout') {
        shouldPrint = _stdoutFilter.shouldPrintLine(line, isNodeSyncing: _statsService.currentStats.isSyncing);
      } else {
        shouldPrint = _stderrFilter.shouldPrintLine(line, isNodeSyncing: _statsService.currentStats.isSyncing);
      }

      if (shouldPrint) {
        String source;
        if (line.isNodeError) {
          source = 'node-error';
        } else if (streamType == 'stdout') {
          source = 'node';
        } else {
          source = 'node';
        }

        final logEntry = LogEntry(message: line, timestamp: DateTime.now(), source: source);
        _logsController.add(logEntry);
        print(source == 'node' ? '[node] $line' : '[node-error] $line');
      }
    }

    _nodeProcess.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      processLogLine(line, 'stdout');
    });

    _nodeProcess.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      processLogLine(line, 'stderr');
    });
  }

  void stop() {
    print('MinerProcess: stop() called. Killing processes.');
    _syncStatusTimer?.cancel();
    _externalMinerApiClient.stopPolling();
    _chainRpcClient.stopPolling();

    // Kill external miner process first
    if (_externalMinerProcess != null) {
      try {
        print('MinerProcess: Attempting to kill external miner process (PID: ${_externalMinerProcess!.pid})');

        // Try graceful termination first
        _externalMinerProcess!.kill(ProcessSignal.sigterm);

        // Wait briefly for graceful shutdown
        Future.delayed(const Duration(seconds: 2)).then((_) async {
          // Check if process is still running and force kill if necessary
          try {
            if (await _isProcessRunning(_externalMinerProcess!.pid)) {
              print('MinerProcess: External miner still running, force killing...');
              _externalMinerProcess!.kill(ProcessSignal.sigkill);
            }
          } catch (e) {
            // Process is already dead, which is what we want
            print('MinerProcess: External miner process already terminated');
          }
        });
      } catch (e) {
        print('MinerProcess: Error killing external miner process: $e');
        // Try force kill as backup
        try {
          _externalMinerProcess!.kill(ProcessSignal.sigkill);
        } catch (e2) {
          print('MinerProcess: Error force killing external miner process: $e2');
        }
      }
    }

    // Kill node process
    try {
      print('MinerProcess: Attempting to kill node process (PID: ${_nodeProcess.pid})');

      // Try graceful termination first
      _nodeProcess.kill(ProcessSignal.sigterm);

      // Wait briefly for graceful shutdown
      Future.delayed(const Duration(seconds: 2)).then((_) async {
        // Check if process is still running and force kill if necessary
        try {
          if (await _isProcessRunning(_nodeProcess.pid)) {
            print('MinerProcess: Node process still running, force killing...');
            _nodeProcess.kill(ProcessSignal.sigkill);
          }
        } catch (e) {
          // Process is already dead, which is what we want
          print('MinerProcess: Node process already terminated');
        }
      });
    } catch (e) {
      print('MinerProcess: Error killing node process: $e');
      // Try force kill as backup
      try {
        _nodeProcess.kill(ProcessSignal.sigkill);
      } catch (e2) {
        print('MinerProcess: Error force killing node process: $e2');
      }
    }

    // Close the logs stream
    if (!_logsController.isClosed) {
      _logsController.close();
    }
  }

  /// Force stop both processes immediately with SIGKILL
  void forceStop() {
    print('MinerProcess: forceStop() called. Force killing processes.');
    _syncStatusTimer?.cancel();

    final List<Future<void>> killFutures = [];

    // Force kill external miner
    if (_externalMinerProcess != null) {
      final minerPid = _externalMinerProcess!.pid;
      killFutures.add(_forceKillProcess(minerPid, 'external miner'));
      try {
        _externalMinerProcess!.kill(ProcessSignal.sigkill);
      } catch (e) {
        print('MinerProcess: Error force killing external miner process: $e');
      }
      _externalMinerProcess = null;
    }

    // Force kill node process
    try {
      final nodePid = _nodeProcess.pid;
      killFutures.add(_forceKillProcess(nodePid, 'node'));
      _nodeProcess.kill(ProcessSignal.sigkill);
    } catch (e) {
      print('MinerProcess: Error force killing node process: $e');
    }

    // Wait for all kills to complete (with timeout)
    Future.wait(killFutures).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('MinerProcess: Force kill operations timed out');
        return [];
      },
    );

    // Close the logs stream
    if (!_logsController.isClosed) {
      _logsController.close();
    }
  }

  /// Check if a process with the given PID is running
  Future<bool> _isProcessRunning(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('tasklist', ['/FI', 'PID eq $pid']);
        return result.stdout.toString().contains(' $pid ');
      } else {
        final result = await Process.run('kill', ['-0', pid.toString()]);
        return result.exitCode == 0;
      }
    } catch (e) {
      return false;
    }
  }

  /// Helper method to force kill a process by PID with verification
  Future<void> _forceKillProcess(int pid, String processName) async {
    try {
      print('MinerProcess: Force killing $processName process (PID: $pid)');

      if (Platform.isWindows) {
        final killResult = await Process.run('taskkill', ['/F', '/PID', pid.toString()]);
        if (killResult.exitCode == 0) {
          print('MinerProcess: Successfully force killed $processName (PID: $pid)');
        } else {
          print('MinerProcess: taskkill failed for $processName (PID: $pid), exit code: ${killResult.exitCode}');
        }

        await Future.delayed(const Duration(milliseconds: 500));

        // Verify
        final checkResult = await Process.run('tasklist', ['/FI', 'PID eq $pid']);
        if (checkResult.stdout.toString().contains(' $pid ')) {
          print('MinerProcess: WARNING - $processName (PID: $pid) may still be running');
          // Try by name as last resort
          final binaryName = processName.contains('miner') ? 'quantus-miner.exe' : 'quantus-node.exe';
          await Process.run('taskkill', ['/F', '/IM', binaryName]);
        } else {
          print('MinerProcess: Verified $processName (PID: $pid) is terminated');
        }
      } else {
        // First try SIGKILL via kill command for better reliability
        final killResult = await Process.run('kill', ['-9', pid.toString()]);

        if (killResult.exitCode == 0) {
          print('MinerProcess: Successfully force killed $processName (PID: $pid)');
        } else {
          print('MinerProcess: kill command failed for $processName (PID: $pid), exit code: ${killResult.exitCode}');
        }

        // Wait a moment then verify the process is dead
        await Future.delayed(const Duration(milliseconds: 500));

        final checkResult = await Process.run('kill', ['-0', pid.toString()]);
        if (checkResult.exitCode != 0) {
          print('MinerProcess: Verified $processName (PID: $pid) is terminated');
        } else {
          print('MinerProcess: WARNING - $processName (PID: $pid) may still be running');
          // Try pkill as last resort
          await Process.run('pkill', ['-9', '-f', processName.contains('miner') ? 'quantus-miner' : 'quantus-node']);
        }
      }
    } catch (e) {
      print('MinerProcess: Error in _forceKillProcess for $processName: $e');
    }
  }

  /// Handle external miner metrics updates
  void _handleExternalMinerMetrics(ExternalMinerMetrics metrics) {
    if (metrics.isHealthy && metrics.hashRate > 0) {
      // Valid metrics received
      _lastValidHashrate = metrics.hashRate;
      _consecutiveMetricsFailures = 0;

      _statsService.updateHashrate(metrics.hashRate);

      // Update workers count from external miner if available
      if (metrics.workers > 0) {
        _statsService.updateWorkers(metrics.workers);
      }

      // Update CPU capacity from external miner if available
      if (metrics.cpuCapacity > 0) {
        _statsService.updateCpuCapacity(metrics.cpuCapacity);
      }

      onStatsUpdate?.call(_statsService.currentStats);
    } else {
      // Invalid or zero metrics
      _consecutiveMetricsFailures++;

      // Only reset to zero after multiple consecutive failures
      if (_consecutiveMetricsFailures >= _maxConsecutiveFailures) {
        _statsService.updateHashrate(0.0);
        _lastValidHashrate = 0.0;
        onStatsUpdate?.call(_statsService.currentStats);
      } else {
        // Keep the last valid hashrate during temporary issues
        if (_lastValidHashrate > 0) {
          _statsService.updateHashrate(_lastValidHashrate);
          onStatsUpdate?.call(_statsService.currentStats);
        }
      }
    }
  }

  /// Handle external miner API errors
  void _handleExternalMinerError(String error) {
    _consecutiveMetricsFailures++;

    // Only reset hashrate after multiple consecutive errors
    if (_consecutiveMetricsFailures >= _maxConsecutiveFailures) {
      if (_statsService.currentStats.hashrate != 0.0) {
        _statsService.updateHashrate(0.0);
        _lastValidHashrate = 0.0;
        onStatsUpdate?.call(_statsService.currentStats);
      }
    }
  }

  /// Check if required ports are available and cleanup if needed
  Future<void> _ensurePortsAvailable() async {
    // Check if external miner port (9833) is in use
    if (await _isPortInUse(externalMinerPort)) {
      await _killProcessOnPort(externalMinerPort);
      await Future.delayed(const Duration(seconds: 1));

      if (await _isPortInUse(externalMinerPort)) {
        throw Exception('Port $externalMinerPort is still in use after cleanup attempt');
      }
    }

    // Check if metrics port (9900) is in use
    if (await _isPortInUse(9900)) {
      await _killProcessOnPort(9900);
      await Future.delayed(const Duration(seconds: 1));

      if (await _isPortInUse(9900)) {
        final altMetricsPort = await _findAvailablePort(9900);
        if (altMetricsPort != 9900) {
          // Update the metrics URL for the API client
          _externalMinerApiClient = ExternalMinerApiClient(
            baseUrl: 'http://127.0.0.1:$externalMinerPort',
            metricsUrl: 'http://127.0.0.1:$altMetricsPort/metrics',
          );
          _externalMinerApiClient.onMetricsUpdate = _handleExternalMinerMetrics;
          _externalMinerApiClient.onError = _handleExternalMinerError;
        }
      }
    }
  }

  /// Find an available port starting from the given port
  Future<int> _findAvailablePort(int startPort) async {
    for (int port = startPort; port <= startPort + 10; port++) {
      if (!(await _isPortInUse(port))) {
        return port;
      }
    }
    return startPort; // Return original if no alternative found
  }

  /// Check if a port is currently in use
  Future<bool> _isPortInUse(int port) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('netstat', ['-ano']);
        return result.exitCode == 0 && result.stdout.toString().contains(':$port');
      } else {
        final result = await Process.run('lsof', ['-i', ':$port']);
        return result.exitCode == 0 && result.stdout.toString().isNotEmpty;
      }
    } catch (e) {
      // lsof might not be available, try netstat as fallback
      try {
        final result = await Process.run('netstat', ['-an']);
        return result.stdout.toString().contains(':$port');
      } catch (e2) {
        print('DEBUG: Could not check port $port availability: $e2');
        return false;
      }
    }
  }

  /// Kill process using a specific port
  Future<void> _killProcessOnPort(int port) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('netstat', ['-ano']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          for (final line in lines) {
            if (line.contains(':$port')) {
              final parts = line.trim().split(RegExp(r'\s+'));
              if (parts.isNotEmpty) {
                final pid = parts.last;
                // Verify it's a valid PID number
                if (int.tryParse(pid) != null) {
                  await Process.run('taskkill', ['/F', '/PID', pid]);
                }
              }
            }
          }
        }
      } else {
        // Find process using the port
        final result = await Process.run('lsof', ['-ti', ':$port']);
        if (result.exitCode == 0) {
          final pids = result.stdout.toString().trim().split('\n');
          for (final pid in pids) {
            if (pid.isNotEmpty) {
              await Process.run('kill', ['-9', pid.trim()]);
            }
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Get the metrics port to use (either 9900 or alternative)
  Future<int> _getMetricsPort() async {
    if (await _isPortInUse(9900)) {
      return await _findAvailablePort(9901);
    }
    return 9900;
  }

  /// Cleanup any existing quantus-miner processes
  Future<void> _cleanupExistingMinerProcesses() async {
    try {
      if (Platform.isWindows) {
        try {
          await Process.run('taskkill', ['/F', '/IM', 'quantus-miner.exe']);
          await Future.delayed(const Duration(seconds: 2));
        } catch (_) {
          // Process might not exist
        }
      } else {
        // Find all quantus-miner processes
        final result = await Process.run('pgrep', ['-f', 'quantus-miner']);
        if (result.exitCode == 0) {
          final pids = result.stdout.toString().trim().split('\n');
          for (final pid in pids) {
            if (pid.isNotEmpty) {
              try {
                // Try graceful termination first
                await Process.run('kill', ['-15', pid.trim()]);
                await Future.delayed(const Duration(seconds: 1));

                // Check if still running, force kill if needed
                final checkResult = await Process.run('kill', ['-0', pid.trim()]);
                if (checkResult.exitCode == 0) {
                  await Process.run('kill', ['-9', pid.trim()]);
                }
              } catch (e) {
                // Ignore cleanup errors
              }
            }
          }

          // Wait a moment for processes to fully terminate
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Cleanup any existing quantus-node processes
  Future<void> _cleanupExistingNodeProcesses() async {
    try {
      if (Platform.isWindows) {
        try {
          await Process.run('taskkill', ['/F', '/IM', 'quantus-node.exe']);
          await Future.delayed(const Duration(seconds: 2));
        } catch (_) {
          // Process might not exist
        }
      } else {
        // Find all quantus-node processes
        final result = await Process.run('pgrep', ['-f', 'quantus-node']);
        if (result.exitCode == 0) {
          final pids = result.stdout.toString().trim().split('\n');
          for (final pid in pids) {
            if (pid.isNotEmpty) {
              try {
                // Try graceful termination first
                await Process.run('kill', ['-15', pid.trim()]);
                await Future.delayed(const Duration(seconds: 2));

                // Check if still running, force kill if needed
                final checkResult = await Process.run('kill', ['-0', pid.trim()]);
                if (checkResult.exitCode == 0) {
                  await Process.run('kill', ['-9', pid.trim()]);
                }
              } catch (e) {
                // Ignore cleanup errors
              }
            }
          }

          // Wait a moment for processes to fully terminate
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Cleanup database lock files that may prevent node startup
  Future<void> _cleanupDatabaseLocks() async {
    try {
      // Get the quantus home directory path
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final lockFilePath = '$quantusHome/node_data/chains/dirac/db/full/LOCK';
      final lockFile = File(lockFilePath);

      if (await lockFile.exists()) {
        // At this point node processes should already be cleaned up
        // Safe to remove the stale lock file
        await lockFile.delete();
      }

      // Also check for other potential lock files
      final dbDir = Directory('$quantusHome/node_data/chains/dirac/db/full');
      if (await dbDir.exists()) {
        await for (final entity in dbDir.list()) {
          if (entity is File && entity.path.contains('LOCK')) {
            try {
              await entity.delete();
            } catch (e) {
              // Ignore cleanup errors
            }
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Check and fix database directory permissions
  Future<void> _ensureDatabaseDirectoryAccess() async {
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final dbPath = '$quantusHome/node_data/chains/dirac/db';
      final dbDir = Directory(dbPath);

      // Create the directory if it doesn't exist
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      // Check if directory is writable
      final testFile = File('$dbPath/test_write_access');
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        // Try to fix permissions
        try {
          await Process.run('chmod', ['-R', '755', dbPath]);
        } catch (permError) {
          // Ignore permission fix errors
        }
      }
    } catch (e) {
      // Ignore directory access errors
    }
  }

  /// Handle chain RPC information updates
  /// Wait for the node RPC to be ready, then start polling
  Future<void> _waitForNodeReadyThenStartRpc() async {
    print('DEBUG: Waiting for node RPC to be ready...');

    // Try to connect to RPC endpoint with exponential backoff
    int attempts = 0;
    const maxAttempts = 20; // Up to ~2 minutes of retries
    Duration delay = const Duration(seconds: 2);

    while (attempts < maxAttempts) {
      try {
        final isReady = await _chainRpcClient.isReachable();
        if (isReady) {
          print('DEBUG: Node RPC is ready! Starting chain RPC polling...');
          _chainRpcClient.startPolling();
          return;
        }
      } catch (e) {
        // Expected during startup
      }

      attempts++;
      print('DEBUG: Node RPC not ready yet (attempt $attempts/$maxAttempts), waiting ${delay.inSeconds}s...');

      await Future.delayed(delay);

      // Exponential backoff, but cap at 10 seconds
      if (delay.inSeconds < 10) {
        delay = Duration(seconds: (delay.inSeconds * 1.5).round());
      }
    }

    print('DEBUG: Failed to connect to node RPC after $maxAttempts attempts. Will retry with polling...');
    // Start polling anyway - the error handling in RPC client will manage failures
    _chainRpcClient.startPolling();
  }

  void _handleChainInfoUpdate(ChainInfo info) {
    print('DEBUG: Successfully received chain info - Peers: ${info.peerCount}, Block: ${info.currentBlock}');

    // Update peer count from RPC (most accurate)
    if (info.peerCount >= 0) {
      _statsService.updatePeerCount(info.peerCount);
      print('DEBUG: Updated peer count to: ${info.peerCount}');
    }

    // Update chain name from RPC
    _statsService.updateChainName(info.chainName);

    // Always update current block and target block from RPC (most authoritative)
    _statsService.setSyncingState(info.isSyncing, info.currentBlock, info.targetBlock ?? info.currentBlock);
    print(
      'DEBUG: Updated blocks - current: ${info.currentBlock}, target: ${info.targetBlock ?? info.currentBlock}, syncing: ${info.isSyncing}, chain: ${info.chainName}',
    );

    onStatsUpdate?.call(_statsService.currentStats);
  }

  /// Handle chain RPC errors
  void _handleChainRpcError(String error) {
    // Only log significant RPC errors, not connection issues during startup
    if (!error.contains('Connection refused') && !error.contains('timeout')) {
      print('Chain RPC error: $error');
    }
  }

  /// Dispose of resources
  void dispose() {
    _syncStatusTimer?.cancel();
    _externalMinerApiClient.dispose();
    _chainRpcClient.dispose();
  }
}
