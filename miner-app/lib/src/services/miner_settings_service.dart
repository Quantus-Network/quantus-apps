import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quantus_miner/src/services/binary_manager.dart'; // Assuming this path is correct

class MinerSettingsService {
  final _storage = const FlutterSecureStorage();

  Future<void> logout() async {
    // 1. Delete stored mnemonic
    try {
      await _storage.delete(key: 'rewards_address_mnemonic');
      print('Mnemonic deleted from secure storage.');
    } catch (e) {
      print('Error deleting mnemonic: $e');
      // Decide if you want to re-throw or just log
    }

    // 2. Delete node identity file (node_key.p2p)
    try {
      final identityDir = await BinaryManager.getQuantusHomeDirectoryPath();
      final identityFile = File('$identityDir/node_key.p2p');
      if (await identityFile.exists()) {
        await identityFile.delete();
        print('Node identity file deleted: ${identityFile.path}');
      } else {
        print('Node identity file not found, skipping deletion.');
      }
    } catch (e) {
      print('Error deleting node identity file: $e');
    }

    // 3. Delete node binary
    try {
      final nodeBinaryPath = await BinaryManager.getNodeBinaryFilePath();
      final binaryFile = File(nodeBinaryPath);
      if (await binaryFile.exists()) {
        await binaryFile.delete();
        print('Node binary file deleted: ${binaryFile.path}');
      } else {
        print('Node binary file not found, skipping deletion.');
      }
    } catch (e) {
      print('Error deleting node binary file: $e');
    }

    // Add any other preference clearing logic here if needed in the future
    // For example, clearing SharedPreferences if used.
  }
}
