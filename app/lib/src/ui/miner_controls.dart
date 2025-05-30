import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/binary_manager.dart';
import '../services/miner_process.dart';
import '../services/prometheus_service.dart';

class MinerControls extends StatefulWidget {
  const MinerControls({super.key});

  @override
  State<MinerControls> createState() => _MinerControlsState();
}

class _MinerControlsState extends State<MinerControls> {
  MinerProcess? _proc;
  double? _hashrate; // We'll keep fetching hashrate but display it elsewhere
  Timer? _poll;
  bool _isAttemptingToggle = false; // To prevent rapid multi-clicks

  Future<void> _toggle() async {
    if (_isAttemptingToggle) return;
    setState(() => _isAttemptingToggle = true);

    if (_proc == null) {
      print('Starting mining');
      final id = File('${await BinaryManager.getQuantusHomeDirectoryPath()}/node_key.p2p');
      final rew = File('${await BinaryManager.getQuantusHomeDirectoryPath()}/rewards-address.txt');
      final binPath = await BinaryManager.getNodeBinaryFilePath();
      final bin = File(binPath);

      if (!await bin.exists()) {
        print('Node binary not found. Cannot start mining.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Node binary not found. Please run setup.')),
          );
        }
        setState(() => _isAttemptingToggle = false);
        return;
      }
      // Potentially clear old data if node fails to start with existing data?
      // For now, we assume data is fine or user handles it manually.

      _proc = MinerProcess(bin, id, rew);
      try {
        await _proc!.start();
        _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
          final h = await PrometheusService.fetchHashrate();
          if (mounted) setState(() => _hashrate = h);
        });
      } catch (e) {
        print('Error starting miner process: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting miner: ${e.toString()}')),
          );
        }
        _proc = null; // Ensure proc is null if start failed
      }
    } else {
      print('Stopping mining');
      _proc!.stop();
      _poll?.cancel();
      _proc = null;
      _hashrate = null;
    }
    if (mounted) {
      setState(() => _isAttemptingToggle = false);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    // If _proc is not null, it means mining was active.
    // We might want to ensure it's stopped, though _proc!.stop() should be called by _toggle.
    // However, if the widget is disposed for other reasons while _proc is active,
    // the process might be left running. This depends on app lifecycle.
    // For safety, one might consider _proc?.stop() here, but it can also be complex
    // if stop() itself has async operations or state changes.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch, // Make children stretch horizontally
        children: [
          Text(
            _proc == null ? 'Status: Not Mining' : 'Status: Mining',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8), // Reduced space a bit
          // Display hashrate separately if needed, or it's handled by another widget
          if (_proc != null && _hashrate != null)
            Text(
              'Hashrate: ${_hashrate!.toStringAsFixed(2)} H/s',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            )
          else if (_proc != null)
            Text(
              'Hashrate: Fetching...',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 20), // Adjusted space
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _proc == null ? Colors.green : Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 15), // Adjusted padding
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              minimumSize: const Size(200, 50), // Ensure a minimum size
            ),
            onPressed: _isAttemptingToggle ? null : _toggle, // Disable button during toggle
            child: Text(_proc == null ? 'Start Mining' : 'Stop Mining'),
          ),
        ],
      );
}
