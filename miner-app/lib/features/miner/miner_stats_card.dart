import 'package:flutter/material.dart';
import 'package:quantus_miner/src/services/mining_stats_service.dart';
import 'package:quantus_miner/src/shared/miner_app_constants.dart';
import 'package:quantus_miner/src/utils/hashrate_formatter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class MinerStatsCard extends StatefulWidget {
  final MiningStats miningStats;

  const MinerStatsCard({super.key, required this.miningStats});

  @override
  State<MinerStatsCard> createState() => _MinerStatsCardState();
}

class _MinerStatsCardState extends State<MinerStatsCard> {
  MiningStats? get _miningStats => widget.miningStats;

  @override
  Widget build(BuildContext context) {
    if (_miningStats != null) {
      return _buildStatsDisplay();
    } else {
      return _buildStatsLoading();
    }
  }

  Container _buildStatsLoading() {
    return Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.white.useOpacity(0.05), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.useOpacity(0.6)),
            ),
          ),
          const SizedBox(width: 16),
          Text('Loading mining stats...', style: TextStyle(color: Colors.white.useOpacity(0.6), fontSize: 16)),
        ],
      ),
    );
  }

  Container _buildStatsDisplay() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: MinerAppConstants.cardHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.useOpacity(0.1), Colors.white.useOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.useOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.useOpacity(0.2), blurRadius: 20, spreadRadius: 1, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6366F1), // Deep purple
                        Color(0xFF1E3A8A), // Deep blue
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  'Mining Performance - ${_miningStats!.chainName}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white.useOpacity(0.9)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Stats grid in 2x2 layout
            Row(
              children: [
                // Left column
                Expanded(
                  child: Column(
                    children: [
                      _buildCompactStat(icon: Icons.people, label: 'Peers', value: '${_miningStats!.peerCount}'),
                      const SizedBox(height: 16),
                      _buildDualStat(
                        icon: Icons.memory,
                        label1: 'CPU',
                        value1: '${_miningStats!.workers} / ${_miningStats!.cpuCapacity}',
                        label2: 'GPU',
                        value2:
                            '${_miningStats!.gpuDevices} / ${_miningStats!.gpuCapacity > 0 ? _miningStats!.gpuCapacity : (_miningStats!.gpuDevices > 0 ? _miningStats!.gpuDevices : "-")}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Right column
                Expanded(
                  child: Column(
                    children: [
                      _buildCompactStat(
                        icon: Icons.speed,
                        label: 'Hashrate',
                        value: HashrateFormatter.format(_miningStats!.hashrate),
                      ),
                      const SizedBox(height: 16),
                      _buildCompactStat(
                        icon: Icons.block,
                        label: 'Block',
                        value: '${_miningStats!.currentBlock} / ${_miningStats!.targetBlock}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDualStat({
    required IconData icon,
    required String label1,
    required String value1,
    required String label2,
    required String value2,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF6366F1), // Deep purple
                Color(0xFF1E3A8A), // Deep blue
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    // const SizedBox(height: 0),
                    Text(
                      label1,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.useOpacity(0.6),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 28, color: Colors.white.useOpacity(0.3)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value2,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    // const SizedBox(height: 2),
                    Text(
                      label2,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.useOpacity(0.6),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStat({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF6366F1), // Deep purple
                Color(0xFF1E3A8A), // Deep blue
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.useOpacity(0.6),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
