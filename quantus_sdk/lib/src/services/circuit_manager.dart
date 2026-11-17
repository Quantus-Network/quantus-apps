import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:quantus_sdk/src/rust/api/wormhole.dart' as wormhole_ffi;

class CircuitManager {
  static const List<String> _requiredFiles = [
    'common.bin',
    'verifier.bin',
    'dummy_proof.bin',
    'private_batch_common.bin',
    'private_batch_verifier.bin',
    'config.json',
  ];

  static Future<String> getCircuitDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return path.join(appDir.path, 'circuits');
  }

  static String getVersionedCircuitDirectory(String circuitBaseDir, {String? version}) {
    final resolvedVersion = version ?? wormhole_ffi.zkCircuitsVersion();
    if (resolvedVersion.isEmpty) throw StateError('ZK circuit version is empty');
    return path.join(circuitBaseDir, 'v$resolvedVersion');
  }

  Future<({String circuitDir, String version, int numLeafProofs, int numExitSlots})> ensureAt(
    String circuitBaseDir,
  ) async {
    final version = wormhole_ffi.zkCircuitsVersion();
    final circuitDir = getVersionedCircuitDirectory(circuitBaseDir, version: version);
    final generatedConfig = await wormhole_ffi.ensureCircuitBinaries(binsDir: circuitBaseDir);
    for (final fileName in _requiredFiles) {
      final file = File(path.join(circuitDir, fileName));
      if (!await file.exists()) {
        throw StateError('Circuit generation completed without $fileName in $circuitDir');
      }
    }

    final generated = parseShape(generatedConfig);
    final persisted = parseShape(await File(path.join(circuitDir, 'config.json')).readAsString());
    if (persisted != generated) {
      throw StateError('Circuit config changed during generation: expected $generated, found $persisted');
    }
    return (
      circuitDir: circuitDir,
      version: version,
      numLeafProofs: persisted.numLeafProofs,
      numExitSlots: persisted.numExitSlots,
    );
  }

  /// Leaf-proof and exit-slot counts of a circuit `config.json`.
  @visibleForTesting
  static ({int numLeafProofs, int numExitSlots}) parseShape(String configJson) {
    final config = jsonDecode(configJson);
    if (config is! Map<String, dynamic>) throw const FormatException('Circuit config must be a JSON object');
    return (
      numLeafProofs: _positiveInt(config, 'num_leaf_proofs'),
      numExitSlots: _positiveInt(config, 'num_exit_slots'),
    );
  }

  static int _positiveInt(Map<String, dynamic> config, String key) {
    final value = config[key];
    if (value is! int || value <= 0) throw FormatException('Invalid $key: $value');
    return value;
  }
}
