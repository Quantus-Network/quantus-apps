import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:quantus_miner/src/services/log_filter_service.dart';
import 'package:quantus_miner/src/shared/extensions/log_string_extension.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('LogProcessor');

/// Represents a single log entry from a process.
class LogEntry {
  /// The log message content.
  final String message;

  /// When the log was received.
  final DateTime timestamp;

  /// Source identifier (e.g., 'node', 'miner', 'node-error').
  final String source;

  /// Whether this is an error-level log.
  final bool isError;

  LogEntry({required this.message, required this.timestamp, required this.source, this.isError = false});

  @override
  String toString() {
    final timeStr = timestamp.toIso8601String().substring(11, 19); // HH:MM:SS
    return '[$timeStr] [$source] $message';
  }
}

/// Callback type for checking if node is currently syncing.
typedef SyncStateProvider = bool Function();

/// Processes stdout/stderr streams from a process and emits filtered LogEntries.
///
/// Handles:
/// - Stream decoding (UTF8)
/// - Line splitting
/// - Log filtering based on keywords and sync state
/// - Error detection
class LogStreamProcessor {
  final String sourceName;
  final LogFilterService _filter;
  final SyncStateProvider? _getSyncState;

  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;

  final _logController = StreamController<LogEntry>.broadcast();

  /// Stream of processed log entries.
  Stream<LogEntry> get logs => _logController.stream;

  /// Whether the processor is currently active.
  bool get isActive => _stdoutSubscription != null || _stderrSubscription != null;

  LogStreamProcessor({required this.sourceName, SyncStateProvider? getSyncState})
    : _filter = LogFilterService(),
      _getSyncState = getSyncState;

  /// Start processing logs from a process.
  ///
  /// Call this after starting the process.
  void attach(Process process) {
    _filter.reset();

    _stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_processStdoutLine);

    _stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_processStderrLine);

    _log.d('Attached to process (PID: ${process.pid})');
  }

  /// Stop processing and release resources.
  void detach() {
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _log.d('Detached from process');
  }

  /// Close the log stream permanently.
  void dispose() {
    detach();
    if (!_logController.isClosed) {
      _logController.close();
    }
  }

  void _processStdoutLine(String line) {
    final shouldPrint = _filter.shouldPrintLine(line, isNodeSyncing: _getSyncState?.call() ?? false);

    if (shouldPrint) {
      final isError = _isErrorLine(line);
      final entry = LogEntry(
        message: line,
        timestamp: DateTime.now(),
        source: isError ? '$sourceName-error' : sourceName,
        isError: isError,
      );
      _logController.add(entry);

      if (isError) {
        _log.w('[$sourceName] $line');
      } else {
        _log.d('[$sourceName] $line');
      }
    }
  }

  void _processStderrLine(String line) {
    // stderr is always potentially important
    final isError = _isErrorLine(line);
    final entry = LogEntry(
      message: line,
      timestamp: DateTime.now(),
      source: isError ? '$sourceName-error' : sourceName,
      isError: isError,
    );
    _logController.add(entry);

    if (isError) {
      _log.w('[$sourceName] $line');
    } else {
      _log.d('[$sourceName] $line');
    }
  }

  bool _isErrorLine(String line) {
    // Use the extension method if available for source-specific checks
    if (sourceName == 'node') {
      return line.isNodeError;
    } else if (sourceName == 'miner') {
      return line.isMinerError;
    }
    // Fallback generic error detection
    final lower = line.toLowerCase();
    return lower.contains('error') || lower.contains('panic') || lower.contains('fatal') || lower.contains('failed');
  }
}
