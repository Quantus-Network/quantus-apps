import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// quantus_sdk/lib/src/services/miner_process.dart
class MinerProcess {
  MinerProcess(this.bin, this.identityPath, this.rewardsPath);

  final File bin;
  final File identityPath;
  final File rewardsPath;
  late Process _p;

  Future<void> start() async {
    _p = await Process.start(bin.path, [
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
    ]);
    _p.stdout.transform(utf8.decoder).listen((l) => debugPrint('[node] $l'));
    _p.stderr.transform(utf8.decoder).listen((l) => debugPrint('[err]  $l'));
  }

  void stop() => _p.kill();
}
