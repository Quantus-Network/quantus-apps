import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show protected;
import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/models/miner_error.dart';
import 'package:quantus_miner/src/services/log_stream_processor.dart';
import 'package:quantus_miner/src/services/process_cleanup_service.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

/// Abstract base class for process managers.
///
/// Provides common functionality for managing external processes like
/// the node and miner processes.
abstract class BaseProcessManager {
  Process? _process;
  late LogStreamProcessor _logProcessor;
  final _errorController = StreamController<MinerError>.broadcast();

  bool _intentionalStop = false;

  /// Tag for logging - subclasses should override
  TaggedLoggerWrapper get log;

  /// Name of this process type (for logging)
  String get processName;

  /// Stream of log entries from the process.
  Stream<LogEntry> get logs => _logProcessor.logs;

  /// Stream of errors (crashes, startup failures).
  Stream<MinerError> get errors => _errorController.stream;

  /// The process ID, or null if not running.
  int? get pid => _process?.pid;

  /// Whether the process is currently running.
  bool get isRunning => _process != null;

  /// Access to the error controller for subclasses
  @protected
  StreamController<MinerError> get errorController => _errorController;

  /// Set the intentional stop flag (for subclasses)
  @protected
  set intentionalStop(bool value) => _intentionalStop = value;

  /// Clear the process reference (for subclasses)
  @protected
  void clearProcess() => _process = null;

  /// Initialize the log processor for a source
  void initLogProcessor(String sourceName, {SyncStateProvider? getSyncState}) {
    _logProcessor = LogStreamProcessor(sourceName: sourceName, getSyncState: getSyncState);
  }

  /// Attach process streams to log processor
  void attachProcess(Process process) {
    _process = process;
    _logProcessor.attach(process);
  }

  /// Create an error for startup failure - subclasses should override
  MinerError createStartupError(dynamic error, [StackTrace? stackTrace]);

  /// Create an error for crash - subclasses should override
  MinerError createCrashError(int exitCode);

  /// Stop the process gracefully.
  ///
  /// Returns a Future that completes when the process has stopped.
  Future<void> stop() async {
    if (_process == null) {
      return;
    }

    _intentionalStop = true;
    final processPid = _process!.pid;
    log.i('Stopping $processName (PID: $processPid)...');

    // Try graceful termination first
    _process!.kill(ProcessSignal.sigterm);

    // Wait for graceful shutdown
    final exited = await _waitForExit(MinerConfig.gracefulShutdownTimeout);

    if (!exited) {
      // Force kill if still running
      log.d('$processName still running, force killing...');
      await _forceKill();
    }

    _cleanup();
    log.i('$processName stopped');
  }

  /// Force stop the process immediately.
  void forceStop() {
    if (_process == null) {
      return;
    }

    _intentionalStop = true;
    final processPid = _process!.pid;
    log.i('Force stopping $processName (PID: $processPid)...');

    try {
      _process!.kill(ProcessSignal.sigkill);
    } catch (e) {
      log.e('Error force killing $processName', error: e);
    }

    // Also use system cleanup as backup
    ProcessCleanupService.forceKillProcess(processPid, processName);

    _cleanup();
  }

  /// Handle process exit.
  void handleExit(int exitCode) {
    if (_intentionalStop) {
      log.d('$processName exited (code: $exitCode) - intentional stop');
    } else {
      log.w('$processName crashed (exit code: $exitCode)');
      _errorController.add(createCrashError(exitCode));
    }
    _cleanup();
  }

  /// Dispose of all resources.
  void dispose() {
    forceStop();
    _logProcessor.dispose();
    if (!_errorController.isClosed) {
      _errorController.close();
    }
  }

  Future<bool> _waitForExit(Duration timeout) async {
    if (_process == null) return true;

    try {
      await _process!.exitCode.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _forceKill() async {
    if (_process == null) return;

    try {
      _process!.kill(ProcessSignal.sigkill);
      await _process!.exitCode.timeout(MinerConfig.processVerificationDelay, onTimeout: () => -1);
    } catch (e) {
      log.e('Error during force kill', error: e);
    }
  }

  void _cleanup() {
    _logProcessor.detach();
    _process = null;
  }
}
