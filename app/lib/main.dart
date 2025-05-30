import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For checking setup status
import 'dart:io'; // For File operations

// Import your setup and dashboard screens
import 'features/setup/node_setup_screen.dart';
import 'features/setup/node_identity_setup_screen.dart';
import 'features/setup/rewards_address_setup_screen.dart';
import 'features/miner/miner_dashboard_screen.dart';
import 'src/services/binary_manager.dart'; // Import BinaryManager

Future<String?> initialRedirect(BuildContext context, GoRouterState state) async {
  const storage = FlutterSecureStorage();
  final currentRoute = state.uri.toString();

  // Check 1: Node Installed
  bool isNodeInstalled = false;
  try {
    final nodeBinaryPath = await BinaryManager.getNodeBinaryFilePath();
    isNodeInstalled = await File(nodeBinaryPath).exists();
  } catch (e) {
    print('Error checking node installation status: $e');
    isNodeInstalled = false;
  }

  if (!isNodeInstalled) {
    return (currentRoute == '/node_setup') ? null : '/node_setup';
  }

  // Check 2: Node Identity Set
  bool isIdentitySet = false;
  try {
    final identityPath = '${await BinaryManager.getQuantusHomeDirectoryPath()}/node_key.p2p';
    isIdentitySet = await File(identityPath).exists();
  } catch (e) {
    print('Error checking node identity status: $e');
    isIdentitySet = false;
  }

  if (!isIdentitySet) {
    return (currentRoute == '/node_identity_setup') ? null : '/node_identity_setup';
  }

  // Check 3: Rewards Address Set
  final rewardsAddressMnemonic = await storage.read(key: 'rewards_address_mnemonic');
  final isRewardsAddressSet = rewardsAddressMnemonic != null;

  if (!isRewardsAddressSet) {
    return (currentRoute == '/rewards_address_setup') ? null : '/rewards_address_setup';
  }

  // If all setup steps are complete, go to the miner dashboard
  return (currentRoute == '/miner_dashboard') ? null : '/miner_dashboard';
}

final _router = GoRouter(
  initialLocation: '/', // Start at a neutral path that will be redirected
  redirect: initialRedirect,
  routes: [
    GoRoute(
      path: '/',
      // Builder is not strictly necessary if initialLocation and redirect handle it,
      // but can be a fallback or initial loading screen.
      builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
    GoRoute(
      path: '/node_setup',
      builder: (context, state) => const NodeSetupScreen(),
    ),
    GoRoute(
      path: '/node_identity_setup',
      builder: (context, state) => const NodeIdentitySetupScreen(),
    ),
    GoRoute(
      path: '/rewards_address_setup',
      builder: (context, state) => const RewardsAddressSetupScreen(),
    ),
    GoRoute(
      path: '/miner_dashboard',
      builder: (context, state) => const MinerDashboardScreen(),
    ),
  ],
);

void main() => runApp(const MinerApp());

class MinerApp extends StatelessWidget {
  const MinerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Quantus Miner',
        theme: ThemeData.dark(useMaterial3: true),
        routerConfig: _router,
      );
}
