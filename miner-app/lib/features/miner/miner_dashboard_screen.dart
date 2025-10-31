import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage
import 'package:go_router/go_router.dart'; // Import GoRouter
import 'package:quantus_miner/src/services/miner_process.dart'; // Import MinerProcess
import 'package:quantus_miner/src/services/miner_settings_service.dart'; // Import the new service
import 'package:quantus_miner/src/services/mining_stats_service.dart'; // Import mining stats service
import 'package:quantus_miner/src/ui/logs_widget.dart'; // Import LogsWidget
import 'package:quantus_miner/src/ui/miner_controls.dart'; // Import MinerControls
import 'package:quantus_sdk/quantus_sdk.dart'; // Assuming quantus_sdk exports necessary components

// Remove explicit imports for internal SDK files
// import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
// import 'package:quantus_sdk/src/services/substrate_service.dart';

// --- Updated Menu Enum ---
enum _MenuValues {
  logout, // Changed from resetApp to logout
}
// --- End Updated Menu Enum ---

class MinerDashboardScreen extends StatefulWidget {
  const MinerDashboardScreen({super.key});

  @override
  State<MinerDashboardScreen> createState() => _MinerDashboardScreenState();
}

class _MinerDashboardScreenState extends State<MinerDashboardScreen> {
  String _walletBalance = 'Loading...';
  String? _walletAddress;
  MiningStats? _miningStats;
  MinerProcess? _currentMinerProcess;

  final _storage = const FlutterSecureStorage(); // Instantiate secure storage
  final _minerSettingsService =
      MinerSettingsService(); // Instantiate the service
  final _miningStatsService =
      MiningStatsService(); // Instantiate mining stats service

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
    _startMiningStatsMonitoring();
  }

  @override
  void dispose() {
    _miningStatsService.stopMonitoring();
    super.dispose();
  }

  void _startMiningStatsMonitoring() {
    _miningStatsService.startMonitoring();
    _miningStatsService.statsStream.listen((stats) {
      if (mounted) {
        setState(() {
          _miningStats = stats;
        });
      }
    });
  }

  void _onMinerProcessChanged(MinerProcess? minerProcess) {
    if (mounted) {
      setState(() {
        _currentMinerProcess = minerProcess;
      });
    }
    // Connect miner process to mining stats service for real hashrate
    _miningStatsService.setMinerProcess(minerProcess);
  }

  Future<void> _fetchWalletBalance() async {
    // Implement actual wallet balance fetching using quantus_sdk
    String? address;
    print('fetching wallet balance');
    try {
      final mnemonic = await _storage.read(key: 'rewards_address_mnemonic');
      print('mnemonic: ${mnemonic?.split(" ").length} words');
      if (mnemonic != null) {
        // Derive keypair from mnemonic using SubstrateService (exported by quantus_sdk)
        // ignore: deprecated_member_use
        final keypair = SubstrateService().nonHDdilithiumKeypairFromMnemonic(
          mnemonic,
        );
        // Use toAccountId function to get the SS58 address (exported by quantus_sdk)
        address = toAccountId(obj: keypair);

        print('address: $address');

        // Fetch balance using SubstrateService (exported by quantus_sdk)
        final balance = await SubstrateService().queryBalance(address);

        print('balance: $balance');

        setState(() {
          // Assuming NumberFormattingService and AppConstants are available via quantus_sdk export
          _walletBalance = NumberFormattingService().formatBalance(
            balance,
            addSymbol: true,
          );
          _walletAddress = address;
        });
      } else {
        setState(() {
          _walletBalance = 'Address not set';
          _walletAddress = null;
        });
        print('Rewards address mnemonic not found. Redirecting to setup...');
        // Example Navigation (requires go_router setup)
        // context.go('/rewards_address_setup');
      }
    } catch (e) {
      setState(() {
        _walletBalance = 'Error fetching balance';
        _walletAddress = address;
      });
      print('Error fetching wallet balance: $e');
    }
  }

  // --- Renamed and Updated Method for Logout ---
  Future<void> _performLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text(
            'This will delete your stored rewards address mnemonic, node identity, and the downloaded node binary. You will need to go through the full setup process again.\n\nAre you sure you want to continue?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _minerSettingsService.logout(); // Call the service method
      if (mounted) {
        context.go('/node_setup'); // Navigate to the first setup screen
      }
    }
  }
  // --- End Renamed and Updated Method for Logout ---

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
                // Custom app bar with glass effect
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  floating: true,
                  pinned: false,
                  flexibleSpace: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: BackdropFilter(
                      filter: ColorFilter.mode(
                        Colors.black.useOpacity(0.1),
                        BlendMode.srcOver,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.useOpacity(0.1),
                              Colors.white.useOpacity(0.05),
                            ],
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.useOpacity(0.1),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              // Logo/Title area
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF00D4FF),
                                          Color(0xFF0099FF),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Quantus Miner',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Menu button with glass effect
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.white.useOpacity(0.1),
                                  border: Border.all(
                                    color: Colors.white.useOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: PopupMenuButton<_MenuValues>(
                                  color: const Color(0xFF1A1A1A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  onSelected: (_MenuValues item) async {
                                    switch (item) {
                                      case _MenuValues.logout:
                                        await _performLogout();
                                        break;
                                    }
                                  },
                                  itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<_MenuValues>>[
                                        PopupMenuItem<_MenuValues>(
                                          value: _MenuValues.logout,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.logout,
                                                color: Colors.red.useOpacity(
                                                  0.8,
                                                ),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Logout (Full Reset)',
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .useOpacity(0.9),
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(
                                      Icons.more_vert,
                                      color: Colors.white.useOpacity(0.7),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Main content
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Status indicator
                      if (_miningStats != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _miningStats!.isSyncing
                                        ? [
                                            const Color(0xFFFF6B35),
                                            const Color(0xFFFF8F65),
                                          ]
                                        : [
                                            const Color(
                                              0xFF6366F1,
                                            ), // Deep purple
                                            const Color(
                                              0xFF1E3A8A,
                                            ), // Deep blue
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (_miningStats!.isSyncing
                                                  ? const Color(0xFFFF6B35)
                                                  : const Color(0xFF6366F1))
                                              .useOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _miningStats!.isSyncing
                                          ? Icons.sync
                                          : Icons.check_circle,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _miningStats!.status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Wallet Balance Card - Premium design
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.useOpacity(0.1),
                              Colors.white.useOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.useOpacity(0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.useOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 1,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Wallet Balance',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.useOpacity(0.9),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white.useOpacity(0.1),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.refresh,
                                        color: Colors.white.useOpacity(0.7),
                                        size: 20,
                                      ),
                                      tooltip: 'Reload Balance',
                                      onPressed: _fetchWalletBalance,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _walletBalance,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6366F1), // Deep purple
                                  letterSpacing: -1,
                                ),
                              ),
                              if (_walletAddress != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.useOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.useOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.link,
                                        color: Colors.white.useOpacity(0.5),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _walletAddress!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.useOpacity(0.6),
                                            fontFamily: 'Fira Code',
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.copy,
                                          color: Colors.white.useOpacity(0.5),
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          // Copy to clipboard
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Mining Stats Card - Compact Professional Design
                      if (_miningStats != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.useOpacity(0.1),
                                Colors.white.useOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.useOpacity(0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.useOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 1,
                                offset: const Offset(0, 8),
                              ),
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
                                      child: const Icon(
                                        Icons.analytics,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Mining Performance',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.useOpacity(0.9),
                                      ),
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
                                          _buildCompactStat(
                                            icon: Icons.people,
                                            label: 'Peers',
                                            value: '${_miningStats!.peerCount}',
                                          ),
                                          const SizedBox(height: 16),
                                          _buildCompactStat(
                                            icon: Icons.block,
                                            label: 'Current',
                                            value:
                                                '${_miningStats!.currentBlock}',
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
                                            value:
                                                '${_miningStats!.hashrate.toStringAsFixed(2)} H/s',
                                          ),
                                          const SizedBox(height: 16),
                                          _buildCompactStat(
                                            icon: Icons.sync,
                                            label: 'Target',
                                            value:
                                                '${_miningStats!.targetBlock}',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(40),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.useOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.useOpacity(0.6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Loading mining stats...',
                                style: TextStyle(
                                  color: Colors.white.useOpacity(0.6),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Mining Controls
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.useOpacity(0.1),
                              Colors.white.useOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.useOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: MinerControls(
                          onMinerProcessChanged: _onMinerProcessChanged,
                        ),
                      ),
                    ]),
                  ),
                ),
                // Logs section
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      height: 300,
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
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.useOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'AUTO-SCROLL',
                                    style: TextStyle(
                                      color: Colors.white.useOpacity(0.6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Logs content
                          Expanded(child: LogsWidget(minerProcess: _currentMinerProcess, maxLines: 200)),
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

  Widget _buildCompactStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
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
