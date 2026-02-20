import 'dart:io';

import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

import 'binary_manager.dart';

final _log = log.withTag('GpuDetection');

class GpuDetectionService {
  /// Detects the number of GPU devices on the system by probing the miner process
  static Future<int> detectGpuCount() async {
    try {
      final binPath = await BinaryManager.getExternalMinerBinaryFilePath();
      final bin = File(binPath);

      if (!await bin.exists()) {
        _log.w('External miner binary not found at $binPath');
        return 0;
      }

      // Start probing from maxGpuProbeCount down to 1
      for (int i = MinerConfig.maxGpuProbeCount; i >= 1; i--) {
        try {
          // Use a very short duration to fail fast or succeed quickly
          // If it succeeds, it will take 1 second.
          // If it fails (too many GPUs requested), it should fail immediately.

          final result = await Process.run(binPath, [
            'benchmark',
            '--cpu-workers',
            '0',
            '--gpu-devices',
            '$i',
            '--duration',
            '1',
          ]);

          if (result.exitCode == 0) {
            // Success! We found the max supported devices (or at least i devices work).
            return i;
          } else {
            // Failed. Check if we can extract the actual count from the error message to shortcut.
            // Message format: "❌ ERROR: Requested X GPU devices but only Y device(s) are available."
            final output = result.stdout.toString() + result.stderr.toString();
            final match = RegExp(r'only (\d+) device\(s\) are available').firstMatch(output);
            if (match != null) {
              final available = int.parse(match.group(1)!);
              return available;
            }
          }
        } catch (e) {
          _log.d('Error probing for $i GPUs', error: e);
        }
      }
    } catch (e) {
      _log.e('Error in GPU detection service', error: e);
    }
    return 0;
  }
}
