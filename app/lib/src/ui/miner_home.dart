import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/binary_manager.dart';
import '../services/miner_process.dart';
import '../services/prometheus_service.dart';

class MinerHome extends StatefulWidget {
  const MinerHome({super.key});

  @override
  State<MinerHome> createState() => _MinerHomeState();
}

class _MinerHomeState extends State<MinerHome> {
  MinerProcess? _proc;
  double? _hashrate;
  Timer? _poll;

  Future<void> _toggle() async {
    if (_proc == null) {
      // final bin = await BinaryManager.ensureNodeBinary(); // Commented out to prevent auto-download
      // TODO: generate or locate these files:
      final id = File('${await BinaryManager.getQuantusHomeDirectoryPath()}/node_key.p2p'); // Use new method
      final rew = File('${await BinaryManager.getQuantusHomeDirectoryPath()}/rewards-address.txt'); // Use new method

      // TODO: Check if binary exists before starting process
      final binPath = await BinaryManager.getNodeBinaryFilePath(); // Use new method
      final bin = File(binPath);
      if (!await bin.exists()) {
        print('Node binary not found. Cannot start mining.');
        // TODO: Show error to user or navigate back to setup
        return;
      }

      _proc = MinerProcess(bin, id, rew);
      await _proc!.start();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
        final h = await PrometheusService.fetchHashrate();
        setState(() => _hashrate = h);
      });
    } else {
      _proc!.stop();
      _poll?.cancel();
      _proc = null;
      _hashrate = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Quantus Miner')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _proc == null ? 'Not mining' : 'Hashrate: ${_hashrate?.toStringAsFixed(2) ?? '…'} H/s',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _toggle,
                child: Text(_proc == null ? 'Start Mining' : 'Stop'),
              ),
            ],
          ),
        ),
      );
}
