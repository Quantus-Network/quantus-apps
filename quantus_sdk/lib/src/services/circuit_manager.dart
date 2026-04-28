import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef CircuitProgressCallback = void Function(double progress, String message);

/// Information about circuit binary status.
class CircuitStatus {
  final bool isAvailable;
  final String? circuitDir;
  final int? totalSizeBytes;
  final String? version;

  /// Number of leaf proofs per aggregation batch (read from config.json).
  final int? numLeafProofs;

  const CircuitStatus({
    required this.isAvailable,
    this.circuitDir,
    this.totalSizeBytes,
    this.version,
    this.numLeafProofs,
  });

  static const unavailable = CircuitStatus(isAvailable: false);
}

/// Manages circuit binary files for ZK proof generation.
///
/// Circuit binaries are bundled as SDK assets and extracted to the app's
/// support directory on first use. Rust FFI requires file paths.
class CircuitManager {
  static const List<String> requiredFiles = [
    'prover.bin',
    'common.bin',
    'verifier.bin',
    'dummy_proof.bin',
    'aggregated_common.bin',
    'aggregated_verifier.bin',
    'aggregated_prover.bin',
    'config.json',
  ];

  static const String _assetPrefix = 'packages/quantus_sdk/assets/circuits';

  static Future<String> getCircuitDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return path.join(appDir.path, 'circuits');
  }

  Future<CircuitStatus> checkStatus() async {
    try {
      final circuitDir = await getCircuitDirectory();
      final dir = Directory(circuitDir);
      if (!await dir.exists()) return CircuitStatus.unavailable;

      int totalSize = 0;
      for (final fileName in requiredFiles) {
        final file = File(path.join(circuitDir, fileName));
        if (!await file.exists()) return CircuitStatus.unavailable;
        totalSize += await file.length();
      }

      String? version;
      int? numLeafProofs;
      try {
        final configFile = File(path.join(circuitDir, 'config.json'));
        if (await configFile.exists()) {
          final config = jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
          version = config['version'] as String?;
          numLeafProofs = config['num_leaf_proofs'] as int?;
        }
      } catch (_) {
        // Ignore config read errors
      }

      return CircuitStatus(
        isAvailable: true,
        circuitDir: circuitDir,
        totalSizeBytes: totalSize,
        version: version,
        numLeafProofs: numLeafProofs,
      );
    } catch (_) {
      return CircuitStatus.unavailable;
    }
  }

  /// Copy bundled SDK asset circuit files onto the filesystem.
  Future<bool> extractCircuitsFromAssets({CircuitProgressCallback? onProgress}) async {
    try {
      final circuitDir = await getCircuitDirectory();
      final dir = Directory(circuitDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      onProgress?.call(0.0, 'Extracting circuit files...');

      int extracted = 0;
      for (final fileName in requiredFiles) {
        onProgress?.call(extracted / requiredFiles.length, 'Extracting $fileName...');
        try {
          final byteData = await rootBundle.load('$_assetPrefix/$fileName');
          final targetFile = File(path.join(circuitDir, fileName));
          await targetFile.writeAsBytes(
            byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
            flush: true,
          );
        } catch (_) {
          await deleteCircuits();
          onProgress?.call(0.0, 'Failed to extract $fileName');
          return false;
        }
        extracted++;
      }

      onProgress?.call(1.0, 'Circuit files ready!');
      return true;
    } catch (e) {
      onProgress?.call(0.0, 'Extraction failed: $e');
      return false;
    }
  }

  Future<void> deleteCircuits() async {
    try {
      final circuitDir = await getCircuitDirectory();
      final dir = Directory(circuitDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Ignore deletion errors
    }
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
