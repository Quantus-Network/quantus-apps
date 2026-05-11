import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('LogFileSink');

/// Append-only, size-rotating log sink for a single source (e.g. 'node', 'miner').
///
/// Writes raw lines to `<QuantusHome>/logs/<source>.log`. When the active file
/// exceeds [MinerConfig.logMaxFileBytes], it is rotated to `<source>.log.1`,
/// existing `<source>.log.N` files are shifted up, and `.N+1` beyond
/// [MinerConfig.logMaxBackupFiles] is deleted.
///
/// Total on-disk budget per source =
///   logMaxFileBytes * (logMaxBackupFiles + 1)  (≈ 10MB by default).
///
/// Fail-early: any I/O error disables the sink for the rest of the session
/// (no silent fallback, no retry storm).
class LogFileSink {
  final String source;

  IOSink? _sink;
  File? _activeFile;
  int _bytesWritten = 0;
  bool _disabled = false;
  bool _initializing = false;
  Future<void>? _pendingInit;

  LogFileSink({required this.source});

  /// Returns the directory holding rotated log files (creates it if needed).
  static Future<Directory> getLogsDirectory() async {
    final home = await BinaryManager.getQuantusHomeDirectoryPath();
    final dir = Directory(p.join(home, MinerConfig.logsDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Append a single line to the log file. A trailing newline is added.
  /// No-op if the sink has been disabled by a prior failure.
  Future<void> writeLine(String line) async {
    if (_disabled) return;

    if (_sink == null) {
      _pendingInit ??= _open();
      await _pendingInit;
      if (_disabled) return;
    }

    try {
      final encoded = utf8.encode('$line\n');
      _sink!.add(encoded);
      _bytesWritten += encoded.length;
      if (_bytesWritten >= MinerConfig.logMaxFileBytes) {
        await _rotate();
      }
    } catch (e, st) {
      _log.e('Write failed for "$source", disabling file logging', error: e, stackTrace: st);
      _disabled = true;
      await _safeClose();
    }
  }

  /// Flush buffered bytes to disk. Best-effort.
  Future<void> flush() async {
    try {
      await _sink?.flush();
    } catch (e, st) {
      _log.w('Flush failed for "$source"', error: e, stackTrace: st);
    }
  }

  /// Close the sink and release the file handle.
  Future<void> close() async {
    await _safeClose();
  }

  Future<void> _open() async {
    if (_initializing) return;
    _initializing = true;
    try {
      final dir = await getLogsDirectory();
      final file = File(p.join(dir.path, '$source.log'));
      if (!await file.exists()) {
        await file.create(recursive: true);
      }
      final stat = await file.stat();
      _activeFile = file;
      _bytesWritten = stat.size;
      _sink = file.openWrite(mode: FileMode.append);
      _log.i('Logging "$source" to ${file.path}');

      if (_bytesWritten >= MinerConfig.logMaxFileBytes) {
        await _rotate();
      }
    } catch (e, st) {
      _log.e('Failed to open log file for "$source", disabling file logging', error: e, stackTrace: st);
      _disabled = true;
      _sink = null;
      _activeFile = null;
    } finally {
      _initializing = false;
      _pendingInit = null;
    }
  }

  /// Rotate active file: shift `.N` -> `.N+1`, drop the oldest, move active -> `.1`,
  /// then reopen a fresh active file.
  Future<void> _rotate() async {
    final active = _activeFile;
    if (active == null) return;

    try {
      await _sink?.flush();
      await _sink?.close();
      _sink = null;

      final dir = active.parent;
      final base = p.basename(active.path);

      // Drop the oldest backup (if exists).
      final oldest = File(p.join(dir.path, '$base.${MinerConfig.logMaxBackupFiles}'));
      if (await oldest.exists()) {
        await oldest.delete();
      }

      // Shift .N -> .N+1, working from oldest to newest.
      for (var i = MinerConfig.logMaxBackupFiles - 1; i >= 1; i--) {
        final src = File(p.join(dir.path, '$base.$i'));
        if (await src.exists()) {
          await src.rename(p.join(dir.path, '$base.${i + 1}'));
        }
      }

      // Move active -> .1, then reopen fresh active file.
      if (MinerConfig.logMaxBackupFiles >= 1) {
        await active.rename(p.join(dir.path, '$base.1'));
      } else {
        await active.delete();
      }

      final fresh = File(p.join(dir.path, base));
      await fresh.create(recursive: true);
      _activeFile = fresh;
      _bytesWritten = 0;
      _sink = fresh.openWrite(mode: FileMode.append);
    } catch (e, st) {
      _log.e('Rotation failed for "$source", disabling file logging', error: e, stackTrace: st);
      _disabled = true;
      await _safeClose();
    }
  }

  Future<void> _safeClose() async {
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {
      // ignore: handle already closed / broken sinks silently here, since we're tearing down
    }
    _sink = null;
    _activeFile = null;
  }
}
