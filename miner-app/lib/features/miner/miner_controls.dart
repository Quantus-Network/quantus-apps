import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/services/miner_wallet_service.dart';
import 'package:quantus_miner/src/services/mining_orchestrator.dart';
import 'package:quantus_miner/src/services/mining_stats_service.dart';
import 'package:quantus_miner/src/shared/extensions/snackbar_extensions.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';

import '../../main.dart';
import '../../src/services/binary_manager.dart';
import '../../src/services/gpu_detection_service.dart';
import '../../src/services/miner_settings_service.dart';

final _log = log.withTag('MinerControls');

class MinerControls extends StatefulWidget {
  final MiningOrchestrator? orchestrator;
  final MiningStats miningStats;
  final Function(MiningOrchestrator?) onOrchestratorChanged;

  const MinerControls({
    super.key,
    required this.orchestrator,
    required this.miningStats,
    required this.onOrchestratorChanged,
  });

  @override
  State<MinerControls> createState() => _MinerControlsState();
}

class _MinerControlsState extends State<MinerControls> {
  bool _isNodeToggling = false;
  bool _isMinerToggling = false;
  int _cpuWorkers = 8;
  int _gpuDevices = 0;
  int _detectedGpuCount = 0;
  String _chainId = MinerConfig.defaultChainId;
  final _settingsService = MinerSettingsService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _detectHardware();
  }

  Future<void> _loadSettings() async {
    final savedCpuWorkers = await _settingsService.getCpuWorkers();
    final savedGpuDevices = await _settingsService.getGpuDevices();
    final savedChainId = await _settingsService.getChainId();

    if (mounted) {
      setState(() {
        _cpuWorkers = savedCpuWorkers ?? (Platform.numberOfProcessors > 0 ? Platform.numberOfProcessors : 8);
        _gpuDevices = savedGpuDevices ?? 0;
        _chainId = savedChainId;
      });
    }
  }

  Future<void> _detectHardware() async {
    final gpuCount = await GpuDetectionService.detectGpuCount();
    if (mounted) {
      setState(() {
        _detectedGpuCount = gpuCount;
      });
    }
  }

  // ============================================================
  // Node Control
  // ============================================================

  Future<void> _toggleNode() async {
    if (_isNodeToggling) return;
    setState(() => _isNodeToggling = true);

    if (!_isNodeRunning) {
      await _startNode();
    } else {
      await _stopNode();
    }

    if (mounted) {
      setState(() => _isNodeToggling = false);
    }
  }

  Future<void> _startNode() async {
    _log.i('Starting node');

    // Reload chain ID in case it was changed in settings
    final chainId = await _settingsService.getChainId();
    if (mounted) {
      setState(() => _chainId = chainId);
    }

    // Get rewards preimage directly from the wallet (not from file)
    final walletService = MinerWalletService();
    final wormholeKeyPair = await walletService.getWormholeKeyPair();
    if (wormholeKeyPair == null) {
      _log.w('No wormhole keypair - wallet not set up');
      if (mounted) {
        context.showWarningSnackbar(title: 'Wallet not configured!', message: 'Please set up your inner hash first.');
      }
      return;
    }

    // Check for required files
    final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
    final identityFile = File('$quantusHome/node_key.p2p');
    final nodeBinPath = await BinaryManager.getNodeBinaryFilePath();
    final nodeBin = File(nodeBinPath);
    final minerBinPath = await BinaryManager.getExternalMinerBinaryFilePath();
    final minerBin = File(minerBinPath);

    if (!await nodeBin.exists()) {
      _log.w('Node binary not found');
      if (mounted) {
        context.showWarningSnackbar(title: 'Node binary not found!', message: 'Please run setup.');
      }
      return;
    }

    // Create new orchestrator
    final orchestrator = MiningOrchestrator();
    widget.onOrchestratorChanged(orchestrator);

    try {
      await orchestrator.startNode(
        MiningSessionConfig(
          nodeBinary: nodeBin,
          minerBinary: minerBin,
          identityFile: identityFile,
          rewardsInnerHash: wormholeKeyPair.rewardsPreimageHex,
          wormholeAddress: wormholeKeyPair.address,
          chainId: _chainId,
          cpuWorkers: _cpuWorkers,
          gpuDevices: _gpuDevices,
          detectedGpuCount: _detectedGpuCount,
        ),
      );
    } catch (e) {
      _log.e('Error starting node', error: e);
      if (mounted) {
        context.showErrorSnackbar(title: 'Error starting node!', message: e.toString());
      }
      orchestrator.dispose();
      widget.onOrchestratorChanged(null);
    }
  }

  Future<void> _stopNode() async {
    _log.i('Stopping node');

    if (widget.orchestrator != null) {
      try {
        await widget.orchestrator!.stopNode();
      } catch (e) {
        _log.e('Error stopping node', error: e);
      }
      widget.orchestrator!.dispose();
    }

    await GlobalMinerManager.cleanup();
    widget.onOrchestratorChanged(null);
  }

  // ============================================================
  // Miner Control
  // ============================================================

  Future<void> _toggleMiner() async {
    if (_isMinerToggling) return;
    setState(() => _isMinerToggling = true);

    if (!_isMining) {
      await _startMiner();
    } else {
      await _stopMiner();
    }

    if (mounted) {
      setState(() => _isMinerToggling = false);
    }
  }

  Future<void> _startMiner() async {
    _log.i('Starting miner');

    if (widget.orchestrator == null) {
      if (mounted) {
        context.showWarningSnackbar(title: 'Node not running!', message: 'Start the node first.');
      }
      return;
    }

    // Check miner binary exists
    final minerBinPath = await BinaryManager.getExternalMinerBinaryFilePath();
    final minerBin = File(minerBinPath);

    if (!await minerBin.exists()) {
      _log.w('Miner binary not found');
      if (mounted) {
        context.showWarningSnackbar(title: 'Miner binary not found!', message: 'Please run setup.');
      }
      return;
    }

    try {
      // Update settings in case they changed while miner was stopped
      widget.orchestrator!.updateMinerSettings(cpuWorkers: _cpuWorkers, gpuDevices: _gpuDevices);

      await widget.orchestrator!.startMiner();
    } catch (e) {
      _log.e('Error starting miner', error: e);
      if (mounted) {
        context.showErrorSnackbar(title: 'Error starting miner!', message: e.toString());
      }
    }
  }

  Future<void> _stopMiner() async {
    _log.i('Stopping miner');

    if (widget.orchestrator != null) {
      try {
        await widget.orchestrator!.stopMiner();
      } catch (e) {
        _log.e('Error stopping miner', error: e);
      }
    }
  }

  // ============================================================
  // State Helpers
  // ============================================================

  bool get _isNodeRunning => widget.orchestrator?.isNodeRunning ?? false;
  bool get _isMining => widget.orchestrator?.isMining ?? false;

  /// Whether miner is starting or running (for disabling settings)
  bool get _isMinerActive {
    final state = widget.orchestrator?.state;
    return state == MiningState.startingMiner || state == MiningState.mining || state == MiningState.stoppingMiner;
  }

  String get _nodeButtonText {
    final state = widget.orchestrator?.state;
    if (state == MiningState.startingNode) return 'Starting...';
    if (state == MiningState.waitingForRpc) return 'Connecting...';
    if (_isNodeRunning) return 'Stop Node';
    return 'Start Node';
  }

  String get _minerButtonText {
    final state = widget.orchestrator?.state;
    if (state == MiningState.startingMiner) return 'Starting...';
    if (state == MiningState.stoppingMiner) return 'Stopping...';
    if (_isMining) return 'Stop Mining';
    return 'Start Mining';
  }

  Color get _nodeButtonColor {
    if (_isNodeRunning) return Colors.orange;
    return Colors.blue;
  }

  Color get _minerButtonColor {
    if (_isMining) return Colors.red;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    // Allow editing settings when miner is stopped (even if node is running)
    // Disable during startingMiner, mining, and stoppingMiner states
    final canEditSettings = !_isMinerActive;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // CPU Workers Control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CPU Workers', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$_cpuWorkers'),
                ],
              ),
              Slider(
                value: _cpuWorkers.toDouble(),
                min: 0,
                max: (Platform.numberOfProcessors > 0 ? Platform.numberOfProcessors : 16).toDouble(),
                divisions: (Platform.numberOfProcessors > 0 ? Platform.numberOfProcessors : 16),
                label: _cpuWorkers.toString(),
                onChanged: canEditSettings
                    ? (value) {
                        final rounded = value.round();
                        setState(() => _cpuWorkers = rounded);
                        _settingsService.saveCpuWorkers(rounded);
                      }
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // GPU Devices Control
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('GPU Devices', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$_gpuDevices / $_detectedGpuCount'),
                ],
              ),
              Slider(
                value: _gpuDevices.toDouble(),
                min: 0,
                max: _detectedGpuCount > 0 ? _detectedGpuCount.toDouble() : 1,
                divisions: _detectedGpuCount > 0 ? _detectedGpuCount : 1,
                label: _gpuDevices.toString(),
                onChanged: canEditSettings
                    ? (value) {
                        final rounded = value.round();
                        setState(() => _gpuDevices = rounded);
                        _settingsService.saveGpuDevices(rounded);
                      }
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Control Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Node Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _nodeButtonColor,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                minimumSize: const Size(140, 50),
              ),
              onPressed: _isNodeToggling ? null : _toggleNode,
              child: Text(_nodeButtonText),
            ),
            const SizedBox(width: 16),

            // Miner Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _minerButtonColor,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                minimumSize: const Size(140, 50),
              ),
              onPressed: (_isMinerToggling || !_isNodeRunning) ? null : _toggleMiner,
              child: Text(_minerButtonText),
            ),
          ],
        ),

        // Status indicator
        if (_isNodeRunning && !_isMining) ...[
          const SizedBox(height: 12),
          Text('Node running - ready to mine', style: TextStyle(color: Colors.green.shade300, fontSize: 12)),
        ],
      ],
    );
  }
}
