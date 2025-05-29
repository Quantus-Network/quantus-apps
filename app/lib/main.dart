import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // For checking setup status

// Import your setup and dashboard screens
import 'features/setup/node_setup_screen.dart';
import 'features/setup/node_identity_setup_screen.dart';
import 'features/setup/rewards_address_setup_screen.dart';
import 'features/miner/miner_dashboard_screen.dart';

// We'll use a FutureProvider or similar for actual checks later,
// but for router redirection, a simple async function with placeholders for checks is sufficient for now.
Future<String?> initialRedirect(BuildContext context, GoRouterState state) async {
  const storage = FlutterSecureStorage();

  // TODO: Implement actual checks for node installed, identity set, and rewards address set
  final isNodeInstalled = false; // Placeholder
  final isIdentitySet = false; // Placeholder
  final rewardsAddressMnemonic = await storage.read(key: 'rewards_address_mnemonic');
  final isRewardsAddressSet = rewardsAddressMnemonic != null;

  if (!isNodeInstalled) {
    return '/node_setup';
  }
  if (!isIdentitySet) {
    return '/node_identity_setup';
  }
  if (!isRewardsAddressSet) {
    return '/rewards_address_setup';
  }

  // If all setup steps are complete, go to the miner dashboard
  return '/miner_dashboard';
}

final _router = GoRouter(
  redirect: initialRedirect,
  routes: [
    GoRoute(
      path: '/',
      redirect: (_, __) => '/node_setup', // Redirect root to node setup initially
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
