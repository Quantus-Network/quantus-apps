import 'dart:io';

import 'package:quantus_miner/src/utils/app_logger.dart';

final _log = log.withTag('DiskSpace');

/// Reports free disk space for the volume that holds a given path.
class DiskSpaceService {
  /// Free bytes on the volume containing [path], or null if it could not be determined.
  ///
  /// Returns null instead of throwing so a failed probe never blocks setup by itself;
  /// callers decide whether an unknown value should be treated as a pass.
  static Future<int?> freeBytesForPath(String path) async {
    try {
      if (Platform.isWindows) {
        final escaped = path.replaceAll("'", "''");
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          "(Get-Item -LiteralPath '$escaped').PSDrive.Free",
        ]);
        if (result.exitCode != 0) {
          _log.w('Free space probe failed for $path: ${result.stderr}');
          return null;
        }
        return int.tryParse(result.stdout.toString().trim());
      }

      // POSIX output format keeps one filesystem per line with a fixed column order:
      // Filesystem, 1024-blocks, Used, Available, Capacity, Mounted on.
      final result = await Process.run('df', ['-kP', path]);
      if (result.exitCode != 0) {
        _log.w('Free space probe failed for $path: ${result.stderr}');
        return null;
      }
      final lines = result.stdout.toString().trim().split('\n');
      if (lines.length < 2) return null;
      final cols = lines.last.trim().split(RegExp(r'\s+'));
      if (cols.length < 4) return null;
      final availableKb = int.tryParse(cols[3]);
      return availableKb == null ? null : availableKb * 1024;
    } catch (e) {
      _log.w('Free space probe failed for $path: $e');
      return null;
    }
  }
}
