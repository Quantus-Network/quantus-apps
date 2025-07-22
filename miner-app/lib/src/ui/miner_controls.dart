import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/binary_manager.dart';
import '../services/miner_process.dart';
// PrometheusService import might not be needed here anymore if hashrate is exclusively from MinerProcess
// import '../services/prometheus_service.dart';

class MinerControls extends StatefulWidget {
  const MinerControls({super.key});

  @override
  State<MinerControls> createState() => _MinerControlsState();
}

class _MinerControlsState extends State<MinerControls> {
  MinerProcess? _proc;
  double? _hashrate;
  // Timer? _poll; // Removed: Hashrate will come from MinerProcess callback
  bool _isAttemptingToggle = false;

  // New state variables for sync status
  bool _isSyncingNode = false;
  int? _currentBlock;
  int? _targetBlock;

  Future<void> _toggle() async {
    if (_isAttemptingToggle) return;
    setState(() => _isAttemptingToggle = true);

    if (_proc == null) {
      print('Starting mining');

      // Check for all required files and binaries
      final id = File(
        '${await BinaryManager.getQuantusHomeDirectoryPath()}/node_key.p2p',
      );
      final rew = File(
        '${await BinaryManager.getQuantusHomeDirectoryPath()}/rewards-address.txt',
      );
      final binPath = await BinaryManager.getNodeBinaryFilePath();
      final bin = File(binPath);
      final minerBinPath = await BinaryManager.getExternalMinerBinaryFilePath();
      final minerBin = File(minerBinPath);

      // Check node binary
      if (!await bin.exists()) {
        print('Node binary not found. Cannot start mining.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Node binary not found. Please run setup.'),
            ),
          );
        }
        setState(() => _isAttemptingToggle = false);
        return;
      }

      // Check external miner binary
      if (!await minerBin.exists()) {
        print('External miner binary not found. Cannot start mining.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'External miner binary not found. Please run setup.',
              ),
            ),
          );
        }
        setState(() => _isAttemptingToggle = false);
        return;
      }

      _proc = MinerProcess(
        bin,
        id,
        rew,
        // Updated to use onMetricsUpdate and new signature
        onMetricsUpdate: (isSyncing, current, target, newHashrate) {
          if (mounted) {
            setState(() {
              _isSyncingNode = isSyncing;
              _currentBlock = current;
              _targetBlock = target;
              _hashrate = newHashrate; // Update hashrate from callback
              // print('UI Updated: Syncing=$isSyncing, Current=$current, Target=$target, Hashrate=$newHashrate');
            });
          }
        },
      );
      try {
        setState(() {
          _isSyncingNode = true;
          _currentBlock = null;
          _targetBlock = null;
          _hashrate = null;
        });
        await _proc!.start();
        // _poll Timer removed - no longer fetching hashrate from here
      } catch (e) {
        print('Error starting miner process: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error starting miner: ${e.toString()}')),
          );
        }
        _proc = null;
        setState(() {
          _isSyncingNode = false;
          _currentBlock = null;
          _targetBlock = null;
          _hashrate = null; // Clear hashrate on error too
        });
      }
    } else {
      print('Stopping mining');
      _proc!.stop();
      // _poll?.cancel(); // _poll removed
      _proc = null;
      _hashrate = null;
      if (mounted) {
        setState(() {
          _isSyncingNode = false;
          _currentBlock = null;
          _targetBlock = null;
        });
      }
    }
    if (mounted) {
      setState(() => _isAttemptingToggle = false);
    }
  }

  @override
  void dispose() {
    // _poll?.cancel(); // _poll removed
    _proc?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String statusText = 'Status: Not Mining';
    if (_proc != null) {
      if (_isSyncingNode) {
        String blockInfo = '';
        if (_currentBlock != null && _targetBlock != null) {
          blockInfo = ' (Block: $_currentBlock/$_targetBlock)';
        } else if (_currentBlock != null) {
          blockInfo = ' (Block: $_currentBlock)';
        }
        statusText = 'Status: Syncing$blockInfo...';
      } else {
        statusText = 'Status: Mining (External Miner)';
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          statusText,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        if (_proc != null && !_isSyncingNode && _hashrate != null)
          Text(
            'Hashrate: ${_hashrate!.toStringAsFixed(2)} H/s',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          )
        else if (_proc != null &&
            !_isSyncingNode &&
            _hashrate == null &&
            !_isSyncingNode) // Show fetching only if not syncing and proc started
          Text(
            'Hashrate: Fetching...',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _proc == null ? Colors.green : Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            minimumSize: const Size(200, 50),
          ),
          onPressed: _isAttemptingToggle ? null : _toggle,
          child: Text(_proc == null ? 'Start Mining' : 'Stop Mining'),
        ),
      ],
    );
  }
}
