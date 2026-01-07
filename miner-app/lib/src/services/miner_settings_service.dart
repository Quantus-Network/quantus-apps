import 'dart:io';

import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MinerSettingsService {
  static const String _keyCpuWorkers = 'cpu_workers';
  static const String _keyGpuDevices = 'gpu_devices';

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

  Future<void> logout() async {
    print('Starting app logout/reset...');

    // 1. Delete node identity file (node_key.p2p)
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final identityFile = File('$quantusHome/node_key.p2p');
      if (await identityFile.exists()) {
        await identityFile.delete();
        print('✅ Node identity file deleted: ${identityFile.path}');
      } else {
        print('ℹ️ Node identity file not found, skipping deletion.');
      }
    } catch (e) {
      print('❌ Error deleting node identity file: $e');
    }

    // 2. Delete rewards address file
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final rewardsFile = File('$quantusHome/rewards-address.txt');
      if (await rewardsFile.exists()) {
        await rewardsFile.delete();
        print('✅ Rewards address file deleted: ${rewardsFile.path}');
      } else {
        print('ℹ️ Rewards address file not found, skipping deletion.');
      }
    } catch (e) {
      print('❌ Error deleting rewards address file: $e');
    }

    // 3. Delete node binary
    try {
      final nodeBinaryPath = await BinaryManager.getNodeBinaryFilePath();
      final binaryFile = File(nodeBinaryPath);
      if (await binaryFile.exists()) {
        await binaryFile.delete();
        print('✅ Node binary file deleted: ${binaryFile.path}');
      } else {
        print('ℹ️ Node binary file not found, skipping deletion.');
      }
    } catch (e) {
      print('❌ Error deleting node binary file: $e');
    }

    // 4. Delete external miner binary
    try {
      final minerBinaryPath = await BinaryManager.getExternalMinerBinaryFilePath();
      final minerFile = File(minerBinaryPath);
      if (await minerFile.exists()) {
        await minerFile.delete();
        print('✅ External miner binary deleted: ${minerFile.path}');
      } else {
        print('ℹ️ External miner binary not found, skipping deletion.');
      }
    } catch (e) {
      print('❌ Error deleting external miner binary: $e');
    }

    // 5. Delete node data directory (blockchain data)
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final nodeDataDir = Directory('$quantusHome/node_data');
      if (await nodeDataDir.exists()) {
        await nodeDataDir.delete(recursive: true);
        print('✅ Node data directory deleted: ${nodeDataDir.path}');
      } else {
        print('ℹ️ Node data directory not found, skipping deletion.');
      }
    } catch (e) {
      print('❌ Error deleting node data directory: $e');
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
          print('✅ Cleaned up archive: ${file.path}');
        }

        // Try to remove bin directory if it's empty
        try {
          await binDir.delete();
          print('✅ Empty bin directory removed: ${binDir.path}');
        } catch (e) {
          // Directory not empty, that's fine
          print('ℹ️ Bin directory not empty, keeping it.');
        }
      } else {
        print('ℹ️ Bin directory not found, skipping cleanup.');
      }
    } catch (e) {
      print('❌ Error cleaning up bin directory: $e');
    }

    // 7. Try to remove the entire .quantus directory if it's empty
    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final quantusDir = Directory(quantusHome);
      if (await quantusDir.exists()) {
        try {
          await quantusDir.delete();
          print('✅ Removed empty .quantus directory: $quantusHome');
        } catch (e) {
          // Directory not empty, that's fine
          print('ℹ️ .quantus directory not empty, keeping it.');
        }
      }
    } catch (e) {
      print('❌ Error removing .quantus directory: $e');
    }

    // 8. Clear SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('✅ SharedPreferences cleared');
    } catch (e) {
      print('❌ Error clearing SharedPreferences: $e');
    }

    print('🎉 App logout/reset complete! You can now go through setup again.');
  }
}
