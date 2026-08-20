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

  Future<({String circuitDir, String version, int numLeafProofs})> ensureAt(String circuitBaseDir) async {
    final version = wormhole_ffi.zkCircuitsVersion();
    final circuitDir = getVersionedCircuitDirectory(circuitBaseDir, version: version);
    final generatedConfig = await wormhole_ffi.ensureCircuitBinaries(binsDir: circuitBaseDir);
    for (final fileName in _requiredFiles) {
      final file = File(path.join(circuitDir, fileName));
      if (!await file.exists()) {
        throw StateError('Circuit generation completed without $fileName in $circuitDir');
      }
    }

    final generatedNumLeafProofs = parseNumLeafProofs(generatedConfig);
    final persistedConfig = await File(path.join(circuitDir, 'config.json')).readAsString();
    final persistedNumLeafProofs = parseNumLeafProofs(persistedConfig);
    if (persistedNumLeafProofs != generatedNumLeafProofs) {
      throw StateError(
        'Circuit config changed during generation: expected $generatedNumLeafProofs leaf proofs, '
        'found $persistedNumLeafProofs',
      );
    }
    return (circuitDir: circuitDir, version: version, numLeafProofs: persistedNumLeafProofs);
  }

  @visibleForTesting
  static int parseNumLeafProofs(String configJson) {
    final config = jsonDecode(configJson);
    if (config is! Map<String, dynamic>) throw const FormatException('Circuit config must be a JSON object');
    final numLeafProofs = config['num_leaf_proofs'];
    if (numLeafProofs is! int || numLeafProofs <= 0) {
      throw FormatException('Invalid num_leaf_proofs: $numLeafProofs');
    }
    return numLeafProofs;
  }
}
