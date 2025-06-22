import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import './binary_manager.dart';
import './log_filter_service.dart';
import './prometheus_service.dart';

/// quantus_sdk/lib/src/services/miner_process.dart
class MinerProcess {
  final File bin;
  final File identityPath;
  final File rewardsPath;
  late Process _nodeProcess;
  Process? _externalMinerProcess;
  late LogFilterService _stdoutFilter;
  late LogFilterService _stderrFilter;
  late PrometheusService _prometheusService;
  Timer? _syncStatusTimer;
  bool _isCurrentlySyncing = true;
  double? _currentHashrate;
  final int minerCores;
  final int externalMinerPort;

  final Function(bool isSyncing, int? currentBlock, int? targetBlock, double? hashrate)? onMetricsUpdate;

  MinerProcess(
    this.bin,
    this.identityPath,
    this.rewardsPath, {
    this.onMetricsUpdate,
    this.minerCores = 8,
    this.externalMinerPort = 9833,
  });

  final _hashrateRegex = RegExp(r"(\d+\.\d+)\s*H/s");
  final _legacyHashrateRegex = RegExp(r"Mining target.* (\d+\.\d+)");

  Future<void> start() async {
    // First, ensure both binaries are available
    print('DEBUG: Ensuring node binary is available...');
    await BinaryManager.ensureNodeBinary();

    print('DEBUG: Ensuring external miner binary is available...');
    final externalMinerBinPath = await BinaryManager.getExternalMinerBinaryFilePath();
    print('DEBUG: External miner expected at: $externalMinerBinPath');

    await BinaryManager.ensureExternalMinerBinary();
    final externalMinerBin = File(externalMinerBinPath);

    print('DEBUG: Checking if external miner binary exists after ensure...');
    if (!await externalMinerBin.exists()) {
      print('DEBUG: ERROR - External miner binary not found at $externalMinerBinPath');
      throw Exception('External miner binary not found at $externalMinerBinPath');
    } else {
      print('DEBUG: External miner binary found at $externalMinerBinPath');

      // Check if it's executable
      final stat = await externalMinerBin.stat();
      print('DEBUG: External miner binary permissions: ${stat.mode.toRadixString(8)}');
    }

    // Start the external miner first
    print('DEBUG: Starting external miner on port $externalMinerPort with $minerCores cores...');
    print('DEBUG: External miner command: ${externalMinerBin.path} --port $externalMinerPort --num-cores $minerCores');

    try {
      _externalMinerProcess = await Process.start(externalMinerBin.path, [
        '--port',
        externalMinerPort.toString(),
        '--num-cores',
        minerCores.toString(),
      ]);
      print('DEBUG: External miner process started successfully with PID: ${_externalMinerProcess!.pid}');
    } catch (e) {
      print('DEBUG: ERROR - Failed to start external miner process: $e');
      throw Exception('Failed to start external miner: $e');
    }

    // Set up external miner log handling
    _externalMinerProcess!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      print('[ext-miner] $line');
    });

    _externalMinerProcess!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      print('[ext-miner-err] $line');
    });

    // Monitor external miner process exit
    _externalMinerProcess!.exitCode.then((exitCode) {
      print('DEBUG: External miner process exited with code: $exitCode');
      if (exitCode != 0) {
        print('DEBUG: External miner crashed! Exit code: $exitCode');
        // Convert exit code to signal name if it's negative
        if (exitCode < 0) {
          final signal = -exitCode;
          print('DEBUG: External miner was killed by signal: $signal');
          // Common signals: 2=SIGINT, 9=SIGKILL, 15=SIGTERM, 30=SIGUSR1
          switch (signal) {
            case 2:
              print('DEBUG: Signal was SIGINT (interrupt)');
              break;
            case 9:
              print('DEBUG: Signal was SIGKILL (force kill)');
              break;
            case 15:
              print('DEBUG: Signal was SIGTERM (termination)');
              break;
            case 30:
              print('DEBUG: Signal was SIGUSR1 (user signal 1)');
              break;
            default:
              print('DEBUG: Unknown signal: $signal');
          }
        }
      }
    });

    // Give the external miner a moment to start up
    print('DEBUG: Waiting 3 seconds for external miner to start up...');
    await Future.delayed(const Duration(seconds: 3));

    // Check if external miner process is still alive
    bool minerStillRunning = true;
    try {
      // Check if the process has exited by looking at its PID
      final pid = _externalMinerProcess!.pid;
      final result = await Process.run('kill', ['-0', pid.toString()]);
      if (result.exitCode != 0) {
        print('DEBUG: External miner process (PID: $pid) is not running');
        minerStillRunning = false;
      } else {
        print('DEBUG: External miner process (PID: $pid) is still running');
      }
    } catch (e) {
      print('DEBUG: Error checking external miner process: $e');
      minerStillRunning = false;
    }

    if (!minerStillRunning) {
      throw Exception('External miner process died during startup');
    }

    // Test if external miner is responding on the port
    print('DEBUG: Testing if external miner is responding on port $externalMinerPort...');
    try {
      final testClient = HttpClient();
      testClient.connectionTimeout = const Duration(seconds: 5);
      final request = await testClient.getUrl(Uri.parse('http://127.0.0.1:$externalMinerPort'));
      final response = await request.close();
      print('DEBUG: External miner test response status: ${response.statusCode}');
      await response.drain(); // Consume the response
      testClient.close();
      print('DEBUG: External miner is responding correctly!');
    } catch (e) {
      print('DEBUG: External miner not responding on port $externalMinerPort: $e');
      print('DEBUG: This might be normal if the miner is still starting up');
    }

    // Now start the node process
    print('DEBUG: Starting node process...');
    final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
    final basePath = p.join(quantusHome, 'node_data');
    await Directory(basePath).create(recursive: true);

    final nodeKeyFileFromFileSystem = await BinaryManager.getNodeKeyFile();
    if (await nodeKeyFileFromFileSystem.exists()) {
      final content = await nodeKeyFileFromFileSystem.readAsString();
      print('DEBUG: Content of nodeKeyFileFromFileSystem (${nodeKeyFileFromFileSystem.path}): $content');
    } else {
      print('DEBUG: nodeKeyFileFromFileSystem (${nodeKeyFileFromFileSystem.path}) does not exist.');
    }

    if (await identityPath.exists()) {
      final identityContent = await identityPath.readAsString();
      print('DEBUG: Content of identityPath file (${identityPath.path}) to be used by node: $identityContent');
    } else {
      print('DEBUG: identityPath file (${identityPath.path}) to be used by node does not exist.');
    }

    final List<String> args = [
      '--base-path',
      basePath,
      '--node-key-file',
      identityPath.path,
      '--rewards-address',
      rewardsPath.path,
      '--validator',
      '--chain',
      'live_resonance',
      '--port',
      '30333',
      '--prometheus-port',
      '9616',
      '--name',
      'QuantusMinerGUI',
      '--external-miner-url',
      'http://127.0.0.1:$externalMinerPort',
    ];

    print('DEBUG: Executing command: ${bin.path}');
    print('DEBUG: With arguments: ${args.join(' ')}');

    _nodeProcess = await Process.start(bin.path, args);
    _stdoutFilter = LogFilterService();
    _stderrFilter = LogFilterService();
    _prometheusService = PrometheusService();

    _stdoutFilter.reset();
    _stderrFilter.reset();
    _currentHashrate = null;

    _isCurrentlySyncing = true;
    onMetricsUpdate?.call(_isCurrentlySyncing, null, null, _currentHashrate);

    _syncStatusTimer?.cancel();
    _syncStatusTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      PrometheusMetrics? metrics = await _prometheusService.fetchMetrics();
      if (metrics != null) {
        bool previousSyncState = _isCurrentlySyncing;
        _isCurrentlySyncing = metrics.isMajorSyncing;

        if (previousSyncState != _isCurrentlySyncing) {
          print('DEBUG: Sync status changed: $previousSyncState -> $_isCurrentlySyncing');
        }
        onMetricsUpdate?.call(_isCurrentlySyncing, metrics.bestBlock, metrics.targetBlock, _currentHashrate);
      } else {
        print('WARNING: Failed to fetch Prometheus metrics. Keeping previous sync state: $_isCurrentlySyncing');
        onMetricsUpdate?.call(_isCurrentlySyncing, null, null, _currentHashrate);
      }
    });

    void processLogLine(String line, String streamType) {
      Match? match = _hashrateRegex.firstMatch(line);
      match ??= _legacyHashrateRegex.firstMatch(line);

      if (match != null && match.groupCount >= 1) {
        final newHashrate = double.tryParse(match.group(1)!);
        if (newHashrate != null && newHashrate != _currentHashrate) {
          _currentHashrate = newHashrate;
          onMetricsUpdate?.call(_isCurrentlySyncing, null, null, _currentHashrate);
        }
      }

      bool shouldPrint;
      if (streamType == 'stdout') {
        shouldPrint = _stdoutFilter.shouldPrintLine(line, isNodeSyncing: _isCurrentlySyncing);
      } else {
        shouldPrint = _stderrFilter.shouldPrintLine(line, isNodeSyncing: _isCurrentlySyncing);
      }

      if (shouldPrint) {
        print(streamType == 'stdout' ? '[node] $line' : '[err]  $line');
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
    _currentHashrate = null;
    onMetricsUpdate?.call(false, null, null, _currentHashrate);

    try {
      _nodeProcess.kill();
    } catch (e) {
      print('MinerProcess: Error killing node process: $e');
    }

    try {
      _externalMinerProcess?.kill();
    } catch (e) {
      print('MinerProcess: Error killing external miner process: $e');
    }
  }
}
