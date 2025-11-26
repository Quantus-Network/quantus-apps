import 'package:flutter/material.dart';
import 'package:quantus_miner/features/settings/settings_app_bar.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getBinaryInfo();
    });
  }

  Future<void> _getBinaryInfo() async {
    // Simulate a tiny delay for smooth UI transition if cached
    // await Future.delayed(const Duration(milliseconds: 300));

    final [nodeUpdateInfo, minerUpdateInfo] = await Future.wait([
      BinaryManager.getNodeBinaryVersion(),
      BinaryManager.getMinerBinaryVersion(),
    ]);

    if (mounted) {
      setState(() {
        _minerUpdateInfo = minerUpdateInfo;
        _nodeUpdateInfo = nodeUpdateInfo;
        _isLoading = false;
      });
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

                        // Example: You could add another section here later
                        // Text('ACCOUNT', style: ...),
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
}
