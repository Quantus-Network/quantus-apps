import 'dart:io';

import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('ProcessCleanup');

/// Service responsible for platform-specific process management operations.
///
/// This includes:
/// - Checking if processes are running
/// - Killing processes by PID or name
/// - Port availability checking and cleanup
/// - Database lock file cleanup
/// - Directory access verification
class ProcessCleanupService {
  ProcessCleanupService._();

  // ============================================================
  // Process Running Checks
  // ============================================================

  /// Check if a process with the given PID is currently running.
  static Future<bool> isProcessRunning(int pid) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('tasklist', ['/FI', 'PID eq $pid']);
        return result.stdout.toString().contains(' $pid ');
      } else {
        // On Unix, kill -0 checks if process exists without killing it
        final result = await Process.run('kill', ['-0', pid.toString()]);
        return result.exitCode == 0;
      }
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // Process Killing
  // ============================================================

  /// Force kill a process by PID with verification.
  ///
  /// Returns true if the process was successfully killed or was already dead.
  static Future<bool> forceKillProcess(int pid, String processName) async {
    try {
      _log.d(' Force killing $processName (PID: $pid)');

      if (Platform.isWindows) {
        return await _forceKillWindowsProcess(pid, processName);
      } else {
        return await _forceKillUnixProcess(pid, processName);
      }
    } catch (e) {
      _log.e('Error killing $processName', error: e);
      return false;
    }
  }

  static Future<bool> _forceKillWindowsProcess(int pid, String processName) async {
    final killResult = await Process.run('taskkill', ['/F', '/PID', pid.toString()]);

    if (killResult.exitCode == 0) {
      _log.d('Killed $processName (PID: $pid)');
    } else {
      _log.w('taskkill failed for $processName (PID: $pid), exit: ${killResult.exitCode}');
    }

    await Future.delayed(MinerConfig.processVerificationDelay);

    // Verify process is dead
    final checkResult = await Process.run('tasklist', ['/FI', 'PID eq $pid']);
    if (checkResult.stdout.toString().contains(' $pid ')) {
      _log.w('$processName (PID: $pid) may still be running');

      // Try by name as last resort
      final binaryName = processName.contains('miner')
          ? MinerConfig.minerBinaryNameWindows
          : MinerConfig.nodeBinaryNameWindows;
      await Process.run('taskkill', ['/F', '/IM', binaryName]);
      return false;
    }

    _log.d('Verified $processName (PID: $pid) terminated');
    return true;
  }

  static Future<bool> _forceKillUnixProcess(int pid, String processName) async {
    // First try SIGKILL via kill command
    final killResult = await Process.run('kill', ['-9', pid.toString()]);

    if (killResult.exitCode == 0) {
      _log.d('Killed $processName (PID: $pid)');
    } else {
      _log.w('kill failed for $processName (PID: $pid), exit: ${killResult.exitCode}');
    }

    await Future.delayed(MinerConfig.processVerificationDelay);

    // Verify process is dead
    final checkResult = await Process.run('kill', ['-0', pid.toString()]);
    if (checkResult.exitCode == 0) {
      _log.w('$processName (PID: $pid) may still be running');

      // Try pkill as last resort
      final binaryName = processName.contains('miner') ? MinerConfig.minerBinaryName : MinerConfig.nodeBinaryName;
      await Process.run('pkill', ['-9', '-f', binaryName]);
      return false;
    }

    _log.d('Verified $processName (PID: $pid) terminated');
    return true;
  }

  /// Kill all processes matching the given binary name.
  static Future<void> killProcessesByName(String binaryName) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/IM', '$binaryName.exe']);
      } else {
        await Process.run('pkill', ['-9', '-f', binaryName]);
      }
    } catch (e) {
      // Ignore errors - processes might not exist
    }
  }

  // ============================================================
  // Port Management
  // ============================================================

  /// Check if a port is currently in use.
  static Future<bool> isPortInUse(int port) async {
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
        _log.d('Could not check port $port availability');
        return false;
      }
    }
  }

  /// Kill any process using the specified port.
  static Future<void> killProcessOnPort(int port) async {
    try {
      if (Platform.isWindows) {
        await _killProcessOnPortWindows(port);
      } else {
        await _killProcessOnPortUnix(port);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  static Future<void> _killProcessOnPortWindows(int port) async {
    final result = await Process.run('netstat', ['-ano']);
    if (result.exitCode != 0) return;

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

  static Future<void> _killProcessOnPortUnix(int port) async {
    final result = await Process.run('lsof', ['-ti', ':$port']);
    if (result.exitCode != 0) return;

    final pids = result.stdout.toString().trim().split('\n');
    for (final pid in pids) {
      if (pid.isNotEmpty) {
        await Process.run('kill', ['-9', pid.trim()]);
      }
    }
  }

  /// Find an available port starting from the given port.
  ///
  /// Tries ports in range [startPort, startPort + MinerConfig.portSearchRange].
  /// Returns the original port if no alternative is found.
  static Future<int> findAvailablePort(int startPort) async {
    for (int port = startPort; port <= startPort + MinerConfig.portSearchRange; port++) {
      if (!(await isPortInUse(port))) {
        return port;
      }
    }
    return startPort; // Return original if no alternative found
  }

  /// Ensure required ports are available, cleaning up if necessary.
  ///
  /// Returns a map of port names to their actual values (may differ from defaults
  /// if an alternative port was needed).
  static Future<Map<String, int>> ensurePortsAvailable({required int quicPort, required int metricsPort}) async {
    final result = <String, int>{'quic': quicPort, 'metrics': metricsPort};

    // Check QUIC port
    if (await isPortInUse(quicPort)) {
      await killProcessOnPort(quicPort);
      await Future.delayed(MinerConfig.portCleanupDelay);

      if (await isPortInUse(quicPort)) {
        throw Exception('Port $quicPort is still in use after cleanup attempt');
      }
    }

    // Check metrics port
    if (await isPortInUse(metricsPort)) {
      await killProcessOnPort(metricsPort);
      await Future.delayed(MinerConfig.portCleanupDelay);

      if (await isPortInUse(metricsPort)) {
        // Try to find an alternative port
        final altPort = await findAvailablePort(metricsPort + 1);
        _log.i('Using alternative metrics port: $altPort');
        result['metrics'] = altPort;
      }
    }

    return result;
  }

  // ============================================================
  // Existing Process Cleanup
  // ============================================================

  /// Cleanup any existing quantus-node processes.
  static Future<void> cleanupExistingNodeProcesses() async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/IM', MinerConfig.nodeBinaryNameWindows]);
        await Future.delayed(MinerConfig.processCleanupDelay);
      } else {
        await _cleanupUnixProcesses(MinerConfig.nodeBinaryName);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Cleanup any existing quantus-miner processes.
  static Future<void> cleanupExistingMinerProcesses() async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/IM', MinerConfig.minerBinaryNameWindows]);
        await Future.delayed(MinerConfig.processCleanupDelay);
      } else {
        await _cleanupUnixProcesses(MinerConfig.minerBinaryName);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  static Future<void> _cleanupUnixProcesses(String processName) async {
    final result = await Process.run('pgrep', ['-f', processName]);
    if (result.exitCode != 0) return;

    final pids = result.stdout.toString().trim().split('\n');
    for (final pid in pids) {
      if (pid.isEmpty) continue;

      try {
        // Try graceful termination first (SIGTERM)
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

    // Wait for processes to fully terminate
    await Future.delayed(MinerConfig.processCleanupDelay);
  }

  // ============================================================
  // Database & Directory Cleanup
  // ============================================================

  /// Cleanup database lock files that may prevent node startup.
  static Future<void> cleanupDatabaseLocks(String chainId) async {
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final lockFilePath = '$quantusHome/node_data/chains/$chainId/db/full/LOCK';
      final lockFile = File(lockFilePath);

      if (await lockFile.exists()) {
        await lockFile.delete();
        _log.d(' Deleted lock file: $lockFilePath');
      }

      // Also check for other potential lock files
      final dbDir = Directory('$quantusHome/node_data/chains/$chainId/db/full');
      if (await dbDir.exists()) {
        await for (final entity in dbDir.list()) {
          if (entity is File && entity.path.contains('LOCK')) {
            try {
              await entity.delete();
              _log.d(' Deleted lock file: ${entity.path}');
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

  /// Check and fix database directory permissions.
  static Future<void> ensureDatabaseDirectoryAccess(String chainId) async {
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final dbPath = '$quantusHome/node_data/chains/$chainId/db';
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
        // Try to fix permissions (Unix only)
        if (!Platform.isWindows) {
          try {
            await Process.run('chmod', ['-R', '755', dbPath]);
          } catch (permError) {
            // Ignore permission fix errors
          }
        }
      }
    } catch (e) {
      // Ignore directory access errors
    }
  }

  // ============================================================
  // Combined Cleanup Operations
  // ============================================================

  /// Perform full cleanup before starting mining.
  ///
  /// This cleans up:
  /// - Existing node processes
  /// - Existing miner processes
  /// - Database locks
  /// - Ensures directory access
  static Future<void> performPreStartCleanup(String chainId) async {
    await cleanupExistingNodeProcesses();
    await cleanupExistingMinerProcesses();
    await cleanupDatabaseLocks(chainId);
    await ensureDatabaseDirectoryAccess(chainId);
  }

  /// Kill all quantus processes by name.
  ///
  /// This is a more aggressive cleanup used during app exit.
  static Future<void> killAllQuantusProcesses() async {
    try {
      _log.d(' Killing all quantus processes...');

      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/IM', MinerConfig.nodeBinaryNameWindows]);
        await Process.run('taskkill', ['/F', '/IM', MinerConfig.minerBinaryNameWindows]);
      } else {
        await Process.run('pkill', ['-9', '-f', MinerConfig.nodeBinaryName]);
        await Process.run('pkill', ['-9', '-f', MinerConfig.minerBinaryName]);
      }

      _log.d(' Cleanup commands executed');
    } catch (e) {
      _log.d(' Error killing processes: $e');
    }
  }
}
