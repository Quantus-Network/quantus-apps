import 'dart:io';

import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = log.withTag('Settings');

class MinerSettingsService {
  static const String _keyCpuWorkers = 'cpu_workers';
  static const String _keyGpuDevices = 'gpu_devices';
  static const String _keyChainId = 'chain_id';

  Future<void> saveCpuWorkers(int cpuWorkers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCpuWorkers, cpuWorkers);
  }

  Future<int?> getCpuWorkers() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCpuWorkers);
  }

  Future<void> saveGpuDevices(int gpuDevices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGpuDevices, gpuDevices);
  }

  Future<int?> getGpuDevices() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyGpuDevices);
  }

  /// Save the selected chain ID.
  Future<void> saveChainId(String chainId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyChainId, chainId);
  }

  /// Get the saved chain ID, returns default if not set.
  Future<String> getChainId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedChainId = prefs.getString(_keyChainId);
    if (savedChainId == null) {
      return MinerConfig.defaultChainId;
    }
    // Validate that the chain ID is still valid
    final validIds = MinerConfig.availableChains.map((c) => c.id).toList();
    if (!validIds.contains(savedChainId)) {
      return MinerConfig.defaultChainId;
    }
    return savedChainId;
  }

  /// Get the ChainConfig for the saved chain ID.
  Future<ChainConfig> getChainConfig() async {
    final chainId = await getChainId();
    return MinerConfig.getChainById(chainId);
  }

  Future<void> logout() async {
    _log.i('Starting app logout/reset...');

    // 1. Delete node identity file (node_key.p2p)
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final identityFile = File('$quantusHome/node_key.p2p');
      if (await identityFile.exists()) {
        await identityFile.delete();
        _log.i('✅ Node identity file deleted: ${identityFile.path}');
      } else {
        _log.d('ℹ️ Node identity file not found, skipping deletion.');
      }
    } catch (e) {
      _log.e('❌ Error deleting node identity file', error: e);
    }

    // 2. Delete rewards address file
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final rewardsFile = File('$quantusHome/rewards-address.txt');
      if (await rewardsFile.exists()) {
        await rewardsFile.delete();
        _log.i('✅ Rewards address file deleted: ${rewardsFile.path}');
      } else {
        _log.d('ℹ️ Rewards address file not found, skipping deletion.');
      }
    } catch (e) {
      _log.e('❌ Error deleting rewards address file', error: e);
    }

    // 3. Delete node binary
    try {
      final nodeBinaryPath = await BinaryManager.getNodeBinaryFilePath();
      final binaryFile = File(nodeBinaryPath);
      if (await binaryFile.exists()) {
        await binaryFile.delete();
        _log.i('✅ Node binary file deleted: ${binaryFile.path}');
      } else {
        _log.d('ℹ️ Node binary file not found, skipping deletion.');
      }
    } catch (e) {
      _log.e('❌ Error deleting node binary file', error: e);
    }

    // 4. Delete external miner binary
    try {
      final minerBinaryPath = await BinaryManager.getExternalMinerBinaryFilePath();
      final minerFile = File(minerBinaryPath);
      if (await minerFile.exists()) {
        await minerFile.delete();
        _log.i('✅ External miner binary deleted: ${minerFile.path}');
      } else {
        _log.d('ℹ️ External miner binary not found, skipping deletion.');
      }
    } catch (e) {
      _log.e('❌ Error deleting external miner binary', error: e);
    }

    // 5. Delete node data directory (blockchain data)
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final nodeDataDir = Directory('$quantusHome/node_data');
      if (await nodeDataDir.exists()) {
        await nodeDataDir.delete(recursive: true);
        _log.i('✅ Node data directory deleted: ${nodeDataDir.path}');
      } else {
        _log.d('ℹ️ Node data directory not found, skipping deletion.');
      }
    } catch (e) {
      _log.e('❌ Error deleting node data directory', error: e);
    }

    // 6. Clean up bin directory and leftover files
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final binDir = Directory('$quantusHome/bin');
      if (await binDir.exists()) {
        // Remove any leftover tar.gz files
        final tarFiles = binDir.listSync().where((file) => file.path.endsWith('.tar.gz'));
        for (var file in tarFiles) {
          await file.delete();
          _log.i('✅ Cleaned up archive: ${file.path}');
        }

        // Try to remove bin directory if it's empty
        try {
          await binDir.delete();
          _log.i('✅ Empty bin directory removed: ${binDir.path}');
        } catch (e) {
          // Directory not empty, that's fine
          _log.d('ℹ️ Bin directory not empty, keeping it.');
        }
      } else {
        _log.d('ℹ️ Bin directory not found, skipping cleanup.');
      }
    } catch (e) {
      _log.e('❌ Error cleaning up bin directory', error: e);
    }

    // 7. Try to remove the entire .quantus directory if it's empty
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final quantusDir = Directory(quantusHome);
      if (await quantusDir.exists()) {
        try {
          await quantusDir.delete();
          _log.i('✅ Removed empty .quantus directory: $quantusHome');
        } catch (e) {
          // Directory not empty, that's fine
          _log.d('ℹ️ .quantus directory not empty, keeping it.');
        }
      }
    } catch (e) {
      _log.e('❌ Error removing .quantus directory', error: e);
    }

    // 8. Clear SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _log.i('✅ SharedPreferences cleared');
    } catch (e) {
      _log.e('❌ Error clearing SharedPreferences', error: e);
    }

    _log.i('🎉 App logout/reset complete!');
  }
}
