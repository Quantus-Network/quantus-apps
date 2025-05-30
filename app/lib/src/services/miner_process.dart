import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import './binary_manager.dart';
import './log_filter_service.dart';

/// quantus_sdk/lib/src/services/miner_process.dart
class MinerProcess {
  final File bin;
  final File identityPath;
  final File rewardsPath;
  late Process _p;
  late LogFilterService _stdoutFilter;
  late LogFilterService _stderrFilter;

  MinerProcess(this.bin, this.identityPath, this.rewardsPath);

  Future<void> start() async {
    final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
    final basePath = p.join(quantusHome, 'node_data');
    await Directory(basePath).create(recursive: true);

    final nodeKeyFileFromFileSystem = await BinaryManager.getNodeKeyFile();
    if (await nodeKeyFileFromFileSystem.exists()) {
      final content = await nodeKeyFileFromFileSystem.readAsString();
      print('DEBUG: Content of nodeKeyFileFromFileSystem (${nodeKeyFileFromFileSystem.path}): $content');
    } else {
      print('DEBUG: nodeKeyFileFromFileSystem (${nodeKeyFileFromFileSystem.path}) does not exist.');
    }

    if (await identityPath.exists()) {
      final identityContent = await identityPath.readAsString();
      print('DEBUG: Content of identityPath file (${identityPath.path}) to be used by node: $identityContent');
    } else {
      print('DEBUG: identityPath file (${identityPath.path}) to be used by node does not exist.');
    }

    final List<String> args = [
      '--base-path',
      basePath,
      '--node-key-file',
      identityPath.path,
      '--rewards-address',
      rewardsPath.path,
      '--validator',
      '--chain',
      'live_resonance',
      '--port',
      '30333',
      '--prometheus-port',
      '9616',
      '--name',
      'QuantusMinerGUI'
    ];

    print('DEBUG: Executing command: ${bin.path}');
    print('DEBUG: With arguments: ${args.join(' ')}');

    _p = await Process.start(bin.path, args);
    _stdoutFilter = LogFilterService();
    _stderrFilter = LogFilterService();

    _p.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      bool shouldPrint = _stdoutFilter.shouldPrintLine(line);
      if (shouldPrint) {
        print('[node] $line');
      }
    });

    _p.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      bool shouldPrint = _stderrFilter.shouldPrintLine(line);
      if (shouldPrint) {
        print('[err]  $line');
      }
    });
  }

  void stop() {
    print('MinerProcess: stop() called. Killing process.');
    try {
      _p.kill();
    } catch (e) {
      print('MinerProcess: Error killing process: $e');
    }
  }
}
