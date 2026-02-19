import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantus_miner/features/miner/miner_balance_card.dart';
import 'package:quantus_miner/features/miner/miner_app_bar.dart';
import 'package:quantus_miner/features/miner/miner_stats_card.dart';
import 'package:quantus_miner/features/miner/miner_status.dart';
import 'package:quantus_miner/src/models/miner_error.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/services/mining_orchestrator.dart';
import 'package:quantus_miner/src/services/mining_stats_service.dart';
import 'package:quantus_miner/src/shared/extensions/snackbar_extensions.dart';
import 'package:quantus_miner/src/ui/logs_widget.dart';
import 'package:quantus_miner/features/miner/miner_controls.dart';
import 'package:quantus_miner/src/ui/update_banner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import '../../main.dart';

class MinerDashboardScreen extends StatefulWidget {
  const MinerDashboardScreen({super.key});

  @override
  State<MinerDashboardScreen> createState() => _MinerDashboardScreenState();
}

class _MinerDashboardScreenState extends State<MinerDashboardScreen> {
  static const binaryUpdatePollingInterval = Duration(minutes: 30);

  BinaryUpdateInfo _minerUpdateInfo = BinaryUpdateInfo(updateAvailable: false);
  double? _minerUpdateProgress;
  Timer? _minerPollingTimer;

  BinaryUpdateInfo _nodeUpdateInfo = BinaryUpdateInfo(updateAvailable: false);
  double? _nodeUpdateProgress;
  Timer? _nodePollingTimer;

  MiningStats _miningStats = MiningStats.empty();

  // The orchestrator manages all mining operations
  MiningOrchestrator? _orchestrator;

  // Subscriptions
  StreamSubscription<MiningStats>? _statsSubscription;
  StreamSubscription<MinerError>? _errorSubscription;
  StreamSubscription<MiningState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeNodeUpdatePolling();
    _initializeMinerUpdatePolling();
  }

  @override
  void dispose() {
    // Clean up subscriptions
    _statsSubscription?.cancel();
    _errorSubscription?.cancel();
    _stateSubscription?.cancel();

    // Clean up orchestrator
    if (_orchestrator != null) {
      _orchestrator!.forceStop();
    }
    GlobalMinerManager.cleanup();

    _invalidateNodeUpdatePolling();
    _invalidateMinerUpdatePolling();

    super.dispose();
  }

  void _onStatsUpdate(MiningStats stats) {
    if (mounted) {
      setState(() {
        _miningStats = stats;
      });
    }
  }

  void _onOrchestratorChanged(MiningOrchestrator? orchestrator) {
    // Cancel old subscriptions
    _statsSubscription?.cancel();
    _errorSubscription?.cancel();
    _stateSubscription?.cancel();

    if (mounted) {
      setState(() {
        _orchestrator = orchestrator;
      });
    }

    // Set up new subscriptions
    if (orchestrator != null) {
      _statsSubscription = orchestrator.statsStream.listen(_onStatsUpdate);
      _errorSubscription = orchestrator.errorStream.listen(_onError);
      _stateSubscription = orchestrator.stateStream.listen(_onStateChange);
    }

    // Register with global manager for cleanup
    GlobalMinerManager.setOrchestrator(orchestrator);
  }

  void _onStateChange(MiningState state) {
    // Trigger rebuild when orchestrator state changes
    // This ensures button labels and UI state update properly
    if (mounted) {
      setState(() {});
    }
  }

  void _onError(MinerError error) {
    if (!mounted) return;

    // Show error to user
    context.showErrorSnackbar(title: _getErrorTitle(error), message: error.message);
  }

  String _getErrorTitle(MinerError error) {
    switch (error.type) {
      case MinerErrorType.minerCrashed:
        return 'Miner Crashed';
      case MinerErrorType.nodeCrashed:
        return 'Node Crashed';
      case MinerErrorType.minerStartupFailed:
        return 'Miner Startup Failed';
      case MinerErrorType.nodeStartupFailed:
        return 'Node Startup Failed';
      case MinerErrorType.metricsConnectionLost:
        return 'Metrics Connection Lost';
      case MinerErrorType.rpcConnectionLost:
        return 'RPC Connection Lost';
      case MinerErrorType.unknown:
        return 'Error';
    }
  }

  void _initializeMinerUpdatePolling() {
    void runTask() async {
      final minerUpdateInfo = await BinaryManager.checkMinerUpdate();

      if (minerUpdateInfo.updateAvailable) {
        setState(() {
          _minerUpdateInfo = minerUpdateInfo;
        });

        _invalidateMinerUpdatePolling();
      }
    }

    _minerPollingTimer = Timer.periodic(binaryUpdatePollingInterval, (_) {
      runTask();
    });

    // Immediate task running on initialize to not wait for polling for first check
    runTask();
  }

  void _invalidateMinerUpdatePolling() {
    if (_minerPollingTimer != null) {
      _minerPollingTimer!.cancel();
      _minerPollingTimer = null;
    }
  }

  void _cleanMinerUpdateInfo() {
    setState(() {
      _minerUpdateInfo = BinaryUpdateInfo(updateAvailable: false);
    });
  }

  void _handleUpdateMiner() async {
    if (_orchestrator?.isMining == true) {
      context.showErrorSnackbar(
        title: 'Miner is running!',
        message: 'To update the binary please stop the miner first.',
      );
      return;
    }

    await BinaryManager.updateMinerBinary(
      onProgress: (progress) {
        setState(() {
          if (progress.totalBytes > 0) {
            _minerUpdateProgress = progress.downloadedBytes / progress.totalBytes;
          } else {
            _minerUpdateProgress = progress.downloadedBytes > 0 ? 1.0 : 0.0;
          }
        });
      },
    );

    _cleanMinerUpdateInfo();
    _initializeMinerUpdatePolling();
    setState(() {
      _minerUpdateProgress = null;
    });
  }

  void _initializeNodeUpdatePolling() {
    void runTask() async {
      final nodeUpdateInfo = await BinaryManager.checkNodeUpdate();

      if (nodeUpdateInfo.updateAvailable) {
        setState(() {
          _nodeUpdateInfo = nodeUpdateInfo;
        });

        _invalidateNodeUpdatePolling();
      }
    }

    _nodePollingTimer = Timer.periodic(binaryUpdatePollingInterval, (_) {
      runTask();
    });

    // Immediate task running on initialize to not wait for polling for first check
    runTask();
  }

  void _invalidateNodeUpdatePolling() {
    if (_nodePollingTimer != null) {
      _nodePollingTimer!.cancel();
      _nodePollingTimer = null;
    }
  }

  void _cleanNodeUpdateInfo() {
    setState(() {
      _nodeUpdateInfo = BinaryUpdateInfo(updateAvailable: false);
    });
  }

  void _handleUpdateNode() async {
    if (_orchestrator?.isMining == true) {
      context.showErrorSnackbar(
        title: 'Miner is running!',
        message: 'To update the binary please stop the miner first.',
      );
      return;
    }

    await BinaryManager.updateNodeBinary(
      onProgress: (progress) {
        setState(() {
          if (progress.totalBytes > 0) {
            _nodeUpdateProgress = progress.downloadedBytes / progress.totalBytes;
          } else {
            _nodeUpdateProgress = progress.downloadedBytes > 0 ? 1.0 : 0.0;
          }
        });
      },
    );

    _cleanNodeUpdateInfo();
    _initializeNodeUpdatePolling();
    setState(() {
      _nodeUpdateProgress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep space black
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)],
                ),
              ),
            ),
            // Main content
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (_minerUpdateInfo.updateAvailable)
                  SliverToBoxAdapter(
                    child: UpdateBanner(
                      updateProgress: _minerUpdateProgress,
                      version: _minerUpdateInfo.latestVersion ?? "undefined",
                      message: 'New miner binary available!',
                      onUpdate: _handleUpdateMiner,
                    ),
                  ),

                if (_nodeUpdateInfo.updateAvailable)
                  SliverToBoxAdapter(
                    child: UpdateBanner(
                      updateProgress: _nodeUpdateProgress,
                      backgroundColor: Colors.green.shade500,
                      version: _nodeUpdateInfo.latestVersion ?? "undefined",
                      message: 'New node binary available!',
                      onUpdate: _handleUpdateNode,
                    ),
                  ),

                // Custom app bar with glass effect
                MinerAppBar(),

                // Main content
                SliverPadding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      MinerStatus(miningStats: _miningStats),

                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 400),
                          child: SizedBox(
                            width: double.infinity,
                            child: MinerControls(
                              orchestrator: _orchestrator,
                              miningStats: _miningStats,
                              onOrchestratorChanged: _onOrchestratorChanged,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildResponsiveCards(),
                    ]),
                  ),
                ),

                // Logs section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child: Container(
                      height: 430,
                      decoration: BoxDecoration(
                        color: Colors.white.useOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.useOpacity(0.1), width: 1),
                      ),
                      child: Column(
                        children: [
                          // Logs header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.white.useOpacity(0.1), width: 1)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.terminal, color: Colors.white.useOpacity(0.7), size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Live Logs',
                                  style: TextStyle(
                                    color: Colors.white.useOpacity(0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Logs content
                          Expanded(child: LogsWidget(orchestrator: _orchestrator, maxLines: 200)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return Row(
            children: [
              Expanded(child: MinerBalanceCard(currentBlock: _miningStats.currentBlock)),
              const SizedBox(width: 16),
              Expanded(child: MinerStatsCard(miningStats: _miningStats)),
            ],
          );
        } else {
          return Column(
            children: [
              MinerBalanceCard(currentBlock: _miningStats.currentBlock),
              MinerStatsCard(miningStats: _miningStats),
            ],
          );
        }
      },
    );
  }
}
