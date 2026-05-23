import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Application-wide logger instance.
///
/// Usage:
/// ```dart
/// import 'package:quantus_miner/src/utils/app_logger.dart';
///
/// log.d('Debug message');
/// log.i('Info message');
/// log.w('Warning message');
/// log.e('Error message', error: e, stackTrace: st);
/// ```
///
/// Log levels:
/// - `d` (debug): Detailed debugging information
/// - `i` (info): General information about app operation
/// - `w` (warning): Potential issues that don't prevent operation
/// - `e` (error): Errors that affect functionality
final Logger log = Logger(
  // In release mode, only show warnings and errors
  // In debug mode, show all logs
  level: kReleaseMode ? Level.warning : Level.all,
  printer: _AppLogPrinter(),
  // No file output for now
  output: null,
);

/// Custom log printer for cleaner console output.
///
/// Format: `[LEVEL] [SOURCE] message`
/// Example: `[D] [MinerProcess] Starting node...`
class _AppLogPrinter extends LogPrinter {
  static final _levelPrefixes = {
    Level.trace: 'T',
    Level.debug: 'D',
    Level.info: 'I',
    Level.warning: 'W',
    Level.error: 'E',
    Level.fatal: 'F',
  };

  static final _levelColors = {
    Level.trace: AnsiColor.fg(AnsiColor.grey(0.5)),
    Level.debug: const AnsiColor.none(),
    Level.info: const AnsiColor.fg(12), // Light blue
    Level.warning: const AnsiColor.fg(208), // Orange
    Level.error: const AnsiColor.fg(196), // Red
    Level.fatal: const AnsiColor.fg(199), // Magenta
  };

  @override
  List<String> log(LogEvent event) {
    final prefix = _levelPrefixes[event.level] ?? '?';
    final color = _levelColors[event.level] ?? const AnsiColor.none();
    final time = _formatTime(event.time);

    final messageStr = event.message.toString();
    final lines = <String>[];

    // Main log line
    lines.add(color('[$time] [$prefix] $messageStr'));

    // Add error if present
    if (event.error != null) {
      lines.add(color('[$time] [$prefix] Error: ${event.error}'));
    }

    // Add stack trace if present (only for errors)
    if (event.stackTrace != null && event.level.index >= Level.error.index) {
      final stackLines = event.stackTrace.toString().split('\n').take(5);
      for (final line in stackLines) {
        if (line.trim().isNotEmpty) {
          lines.add(color('[$time] [$prefix]   $line'));
        }
      }
    }

    return lines;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

/// Extension to make logging from specific sources cleaner.
///
/// Usage:
/// ```dart
/// final _log = log.withTag('MinerProcess');
/// _log.d('Starting...');  // Output: [D] [MinerProcess] Starting...
/// ```
extension TaggedLogger on Logger {
  /// Create a logger that prefixes all messages with a tag.
  TaggedLoggerWrapper withTag(String tag) => TaggedLoggerWrapper(this, tag);
}

/// Wrapper that adds a tag prefix to all log messages.
class TaggedLoggerWrapper {
  final Logger _logger;
  final String _tag;

  TaggedLoggerWrapper(this._logger, this._tag);

  void t(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    _logger.t('[$_tag] $message', time: time, error: error, stackTrace: stackTrace);
  }

  void d(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    _logger.d('[$_tag] $message', time: time, error: error, stackTrace: stackTrace);
  }

  void i(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    _logger.i('[$_tag] $message', time: time, error: error, stackTrace: stackTrace);
  }

  void w(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    _logger.w('[$_tag] $message', time: time, error: error, stackTrace: stackTrace);
  }

  void e(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    _logger.e('[$_tag] $message', time: time, error: error, stackTrace: stackTrace);
  }

  void f(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    _logger.f('[$_tag] $message', time: time, error: error, stackTrace: stackTrace);
  }
}
