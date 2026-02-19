import 'package:flutter/material.dart';
import 'package:quantus_miner/features/settings/settings_app_bar.dart';
import 'package:quantus_miner/main.dart';
import 'package:quantus_miner/src/config/miner_config.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/services/miner_settings_service.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  BinaryVersion? _minerUpdateInfo;
  BinaryVersion? _nodeUpdateInfo;
  bool _isLoading = true;

  // Chain selection
  final MinerSettingsService _settingsService = MinerSettingsService();
  String _selectedChainId = MinerConfig.defaultChainId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final [nodeUpdateInfo, minerUpdateInfo] = await Future.wait([
      BinaryManager.getNodeBinaryVersion(),
      BinaryManager.getMinerBinaryVersion(),
    ]);

    final chainId = await _settingsService.getChainId();

    if (mounted) {
      setState(() {
        _minerUpdateInfo = minerUpdateInfo;
        _nodeUpdateInfo = nodeUpdateInfo;
        _selectedChainId = chainId;
        _isLoading = false;
      });
    }
  }

  Future<void> _onChainChanged(String? newChainId) async {
    if (newChainId == null || newChainId == _selectedChainId) return;

    // Check if mining is currently running
    final orchestrator = GlobalMinerManager.getOrchestrator();
    final isMining = orchestrator?.isRunning ?? false;

    if (isMining) {
      // Show warning dialog
      final shouldChange = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Stop Mining?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Changing the chain requires stopping mining first. '
            'Do you want to stop mining and switch chains?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.white.useOpacity(0.7))),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF00E676)),
              child: const Text('Stop & Switch'),
            ),
          ],
        ),
      );

      if (shouldChange != true) return;

      // Stop mining
      await orchestrator?.stop();
    }

    // Save the new chain ID
    await _settingsService.saveChainId(newChainId);

    if (mounted) {
      setState(() {
        _selectedChainId = newChainId;
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${MinerConfig.getChainById(newChainId).displayName}'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define a theme-consistent accent color (e.g., a tech green or teal)
    const Color accentColor = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep space black
      body: SafeArea(
        child: Stack(
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A0A0A), Color(0xFF141414)],
                ),
              ),
            ),

            // Content
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SettingsAppBar(), // Assuming this is a SliverAppBar or similar

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
                        Text(
                          'SYSTEM INFORMATION',
                          style: TextStyle(
                            color: Colors.white.useOpacity(0.5),
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Node Binary Card
                        _buildInfoTile(
                          title: 'Node Version',
                          version: _nodeUpdateInfo?.version,
                          icon: Icons.dns_rounded,
                          accentColor: accentColor,
                          isLoading: _isLoading,
                        ),

                        const SizedBox(height: 12),

                        // Miner Binary Card
                        _buildInfoTile(
                          title: 'Miner Version',
                          version: _minerUpdateInfo?.version,
                          icon: Icons.memory_rounded, // Chip icon suits "Miner"
                          accentColor: accentColor,
                          isLoading: _isLoading,
                        ),

                        const SizedBox(height: 32),

                        // Network Section Header
                        Text(
                          'NETWORK',
                          style: TextStyle(
                            color: Colors.white.useOpacity(0.5),
                            fontSize: 12,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Chain Selector
                        _buildChainSelector(accentColor),

                        const SizedBox(height: 32),
                      ],
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

  Widget _buildInfoTile({
    required String title,
    required String? version,
    required IconData icon,
    required Color accentColor,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C), // Slightly lighter than background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.useOpacity(0.05), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.useOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accentColor.useOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),

          // Version Number or Loading
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.useOpacity(0.3)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.useOpacity(0.1)),
              ),
              child: Text(
                version ?? 'Unknown',
                style: TextStyle(
                  color: Colors.white.useOpacity(0.9),
                  fontFamily: 'Courier', // Monospace for tech feel
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChainSelector(Color accentColor) {
    final selectedChain = MinerConfig.getChainById(_selectedChainId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.useOpacity(0.05), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.useOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accentColor.useOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.link_rounded, color: accentColor, size: 20),
          ),
          const SizedBox(width: 16),

          // Title and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chain',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(selectedChain.description, style: TextStyle(color: Colors.white.useOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),

          // Dropdown
          if (_isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.useOpacity(0.3)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.useOpacity(0.1)),
              ),
              child: DropdownButton<String>(
                value: _selectedChainId,
                dropdownColor: const Color(0xFF1C1C1C),
                underline: const SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: Colors.white.useOpacity(0.7)),
                style: TextStyle(
                  color: Colors.white.useOpacity(0.9),
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                items: MinerConfig.availableChains.map((chain) {
                  return DropdownMenuItem<String>(value: chain.id, child: Text(chain.displayName));
                }).toList(),
                onChanged: _onChainChanged,
              ),
            ),
        ],
      ),
    );
  }
}
