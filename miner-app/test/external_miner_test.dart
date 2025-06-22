import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'dart:io';

void main() {
  group('External Miner Binary Management', () {
    test('should get external miner binary file path', () async {
      final path = await BinaryManager.getExternalMinerBinaryFilePath();
      expect(path, isNotNull);
      expect(path, contains('external-miner'));
      expect(path, contains('.quantus'));
    });

    test('should check if external miner binary exists', () async {
      final exists = await BinaryManager.hasExternalMinerBinary();
      expect(exists, isA<bool>());
      // The binary might not exist, so we just check the method works
    });

    test('should have different paths for node and external miner', () async {
      final nodePath = await BinaryManager.getNodeBinaryFilePath();
      final minerPath = await BinaryManager.getExternalMinerBinaryFilePath();

      expect(nodePath, isNot(equals(minerPath)));
      expect(nodePath, contains('quantus-node'));
      expect(minerPath, contains('external-miner'));
    });
  });
}
