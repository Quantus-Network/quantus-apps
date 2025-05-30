import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import './binary_manager.dart';

/// quantus_sdk/lib/src/services/miner_process.dart
class MinerProcess {
  MinerProcess(this.bin, this.identityPath, this.rewardsPath);

  final File bin;
  final File identityPath;
  final File rewardsPath;
  late Process _p;

  Future<void> start() async {
    final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
    final basePath = p.join(quantusHome, 'node_data');
    // Ensure the base path directory exists
    await Directory(basePath).create(recursive: true);

    final List<String> args = [
      // '--base-path',
      // basePath,
      // '--node-key-file',
      // identityPath.path,
      // '--rewards-address',
      // rewardsPath.path,
      // '--validator',
      '--chain',
      'live_resonance',
      // '--port',
      // '30333',
      // '--prometheus-port',
      // '9616',
      // '--name',
      // 'QuantusMinerGUI'
    ];

    // Print the command and arguments
    print('DEBUG: Executing command: ${bin.path}');
    print('DEBUG: With arguments: ${args.join(' ')}');

    _p = await Process.start(bin.path, args);
    _p.stdout.transform(utf8.decoder).listen((l) => print('[node] $l'));
    _p.stderr.transform(utf8.decoder).listen((l) => print('[err]  $l'));
  }

  void stop() => _p.kill();
}
