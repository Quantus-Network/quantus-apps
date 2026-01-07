import 'dart:io';

import 'binary_manager.dart';

class GpuDetectionService {
  /// Detects the number of GPU devices on the system by probing the miner process
  static Future<int> detectGpuCount() async {
    try {
      final binPath = await BinaryManager.getExternalMinerBinaryFilePath();
      final bin = File(binPath);

      if (!await bin.exists()) {
        print('External miner binary not found at $binPath');
        return 0;
      }

      // Start probing from 8 down to 1
      for (int i = 8; i >= 1; i--) {
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
          print('Error probing for $i GPUs: $e');
        }
      }
    } catch (e) {
      print('Error in GPU detection service: $e');
    }
    return 0;
  }
}
