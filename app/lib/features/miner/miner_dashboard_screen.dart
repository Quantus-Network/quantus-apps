import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage
import 'package:go_router/go_router.dart'; // Import GoRouter
import 'package:quantus_sdk/quantus_sdk.dart'; // Assuming quantus_sdk exports necessary components
import 'package:quantus_miner/src/services/miner_settings_service.dart'; // Import the new service

// Remove explicit imports for internal SDK files
// import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;
// import 'package:quantus_sdk/src/core/services/substrate_service.dart';

// --- Updated Menu Enum ---
enum _MenuValues {
  logout, // Changed from resetApp to logout
}
// --- End Updated Menu Enum ---

class MinerDashboardScreen extends StatefulWidget {
  const MinerDashboardScreen({super.key});

  @override
  _MinerDashboardScreenState createState() => _MinerDashboardScreenState();
}

class _MinerDashboardScreenState extends State<MinerDashboardScreen> {
  String _walletBalance = 'Loading...';
  String? _walletAddress;
  bool _isMining = false;
  String _miningStats = 'Fetching stats...'; // Placeholder for aggregated stats

  final _storage = const FlutterSecureStorage(); // Instantiate secure storage
  final _minerSettingsService = MinerSettingsService(); // Instantiate the service

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
    _fetchMiningStats();
  }

  @override
  void dispose() {
    // TODO: Dispose resources like timers and process if running
    super.dispose();
  }

  Future<void> _fetchWalletBalance() async {
    // Implement actual wallet balance fetching using quantus_sdk
    String? address;
    print('fetching wallet balance');
    try {
      final mnemonic = await _storage.read(key: 'rewards_address_mnemonic');
      print('mnemonic: $mnemonic');
      if (mnemonic != null) {
        // Derive keypair from mnemonic using SubstrateService (exported by quantus_sdk)
        final keypair = SubstrateService().dilithiumKeypairFromMnemonic(mnemonic);
        // Use toAccountId function to get the SS58 address (exported by quantus_sdk)
        address = toAccountId(obj: keypair);

        print('address: $address');

        // Fetch balance using SubstrateService (exported by quantus_sdk)
        final balance = await SubstrateService().queryBalance(address);

        setState(() {
          // Assuming NumberFormattingService and AppConstants are available via quantus_sdk export
          _walletBalance = '${NumberFormattingService().formatBalance(balance)} ${AppConstants.tokenSymbol}';
          _walletAddress = address;
        });
      } else {
        setState(() {
          _walletBalance = 'Address not set';
          _walletAddress = null;
        });
        // TODO: Implement navigation to rewards address setup screen
        print('Rewards address mnemonic not found. Redirecting to setup...');
        // Example Navigation (requires go_router setup)
        // context.go('/rewards_address_setup');
      }
    } catch (e) {
      setState(() {
        _walletBalance = 'Error fetching balance';
        _walletAddress = address;
      });
      // TODO: Show a more user-friendly error message (e.g., Snackbar)
      print('Error fetching wallet balance: $e');
    }
  }

  Future<void> _fetchMiningStats() async {
    // TODO: Implement actual mining stats fetching
    // This could involve fetching from the node via quantus_sdk or a Prometheus endpoint.
    await Future.delayed(const Duration(seconds: 1)); // Placeholder delay
    setState(() {
      _miningStats = 'Hashrate: 1.2 TH/s\\nShares: 1000\\nLast Reward: 0.01 QUAN'; // Simulated stats
    });
  }

  void _toggleMining() {
    setState(() {
      _isMining = !_isMining;
      // TODO: Call quantus_sdk function to start or stop mining based on _isMining
      if (_isMining) {
        print('Starting mining...');
        // Call start mining function
      } else {
        print('Stopping mining...');
        // Call stop mining function
      }
    });
  }

  // --- Renamed and Updated Method for Logout ---
  Future<void> _performLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text(
              'This will delete your stored rewards address mnemonic, node identity, and the downloaded node binary. You will need to go through the full setup process again.\n\nAre you sure you want to continue?'),
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
      appBar: AppBar(
        title: const Text('Quantus Miner'),
        actions: [
          PopupMenuButton<_MenuValues>(
            onSelected: (_MenuValues item) async {
              switch (item) {
                case _MenuValues.logout: // Updated to logout
                  await _performLogout(); // Call the new logout method
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<_MenuValues>>[
              const PopupMenuItem<_MenuValues>(
                value: _MenuValues.logout, // Updated to logout
                child: Text('Logout (Full Reset)'), // Updated text
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wallet Balance Section (Left)
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Wallet Balance:',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  tooltip: 'Reload Balance',
                                  onPressed: _fetchWalletBalance,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _walletBalance,
                              style: const TextStyle(fontSize: 24, color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                            if (_walletAddress != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _walletAddress!,
                                  style: const TextStyle(fontSize: 14, color: Colors.black54, fontFamily: 'Fira Code'),
                                ),
                              ),
                            // TODO: Potentially add recent transactions or address here
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Mine Button Section (Right)
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _toggleMining,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isMining ? Colors.blue : Colors.green, // Button color changes
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          child: Text(
                            _isMining ? 'Stop Mining' : 'Start Mining',
                          ),
                        ),
                        // TODO: Add small indicator for mining status (e.g., animated icon)
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Stats Panel (Below)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mining Stats:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _miningStats,
                      style: const TextStyle(fontSize: 16),
                    ),
                    // TODO: Format stats nicely, possibly with specific labels
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
