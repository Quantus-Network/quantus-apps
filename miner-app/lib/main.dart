import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:ui';

import 'features/setup/node_setup_screen.dart';
import 'features/setup/node_identity_setup_screen.dart';
import 'features/setup/rewards_address_setup_screen.dart';
import 'features/miner/miner_dashboard_screen.dart';
import 'src/services/binary_manager.dart';
import 'src/services/miner_process.dart';

import 'package:quantus_sdk/quantus_sdk.dart';

/// Global class to manage miner process lifecycle
class GlobalMinerManager {
  static MinerProcess? _globalMinerProcess;

  static void setMinerProcess(MinerProcess? process) {
    _globalMinerProcess = process;
    print('GlobalMinerManager: Set miner process: ${process != null}');
  }

  static MinerProcess? getMinerProcess() {
    return _globalMinerProcess;
  }

  static Future<void> cleanup() async {
    print('GlobalMinerManager: Starting cleanup...');
    if (_globalMinerProcess != null) {
      try {
        print('GlobalMinerManager: Force stopping global miner process');
        _globalMinerProcess!.forceStop();
        _globalMinerProcess = null;
      } catch (e) {
        print('GlobalMinerManager: Error stopping miner process: $e');
      }
    }

    // Kill any remaining quantus processes
    await _killQuantusProcesses();
  }

  static Future<void> _killQuantusProcesses() async {
    try {
      print('GlobalMinerManager: Killing quantus processes by name...');

      // Kill all quantus processes
      await Process.run('pkill', ['-9', '-f', 'quantus-node']);
      await Process.run('pkill', ['-9', '-f', 'quantus-miner']);

      print('GlobalMinerManager: Cleanup commands executed');
    } catch (e) {
      print('GlobalMinerManager: Error killing processes by name: $e');
    }
  }
}

Future<String?> initialRedirect(
  BuildContext context,
  GoRouterState state,
) async {
  final currentRoute = state.uri.toString();

  print('initialRedirect');

  // Check 1: Node Installed
  bool isNodeInstalled = false;
  try {
    isNodeInstalled = await BinaryManager.hasBinary();
    print('isNodeInstalled: $isNodeInstalled');
  } catch (e) {
    print('Error checking node installation status: $e');
    isNodeInstalled = false;
  }

  if (!isNodeInstalled) {
    print('node not installed, going to node setup');
    return (currentRoute == '/node_setup') ? null : '/node_setup';
  }

  // Check 2: Node Identity Set
  bool isIdentitySet = false;
  try {
    final identityPath =
        '${await BinaryManager.getQuantusHomeDirectoryPath()}/node_key.p2p';
    isIdentitySet = await File(identityPath).exists();
  } catch (e) {
    print('Error checking node identity status: $e');
    isIdentitySet = false;
  }

  if (!isIdentitySet) {
    return (currentRoute == '/node_identity_setup')
        ? null
        : '/node_identity_setup';
  }

  // Check 3: Rewards Address Set
  bool isRewardsAddressSet = false;
  try {
    final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
    final rewardsFile = File('$quantusHome/rewards-address.txt');
    isRewardsAddressSet = await rewardsFile.exists();
  } catch (e) {
    print('Error checking rewards address status: $e');
    isRewardsAddressSet = false;
  }

  if (!isRewardsAddressSet) {
    return (currentRoute == '/rewards_address_setup')
        ? null
        : '/rewards_address_setup';
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
      builder: (context, state) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter bindings are initialized

  // Note: Startup cleanup removed for simplicity

  try {
    await QuantusSdk.init();
    print('SubstrateService and QuantusSdk initialized successfully.');
  } catch (e) {
    print('Error initializing SDK: $e');
    // Depending on the app, you might want to show an error UI or prevent app startup
  }
  runApp(const MinerApp());
}

class MinerApp extends StatefulWidget {
  const MinerApp({super.key});

  @override
  State<MinerApp> createState() => _MinerAppState();
}

class _MinerAppState extends State<MinerApp> {
  late AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();

    // Initialize the modern AppLifecycleListener
    _lifecycleListener = AppLifecycleListener(
      onDetach: _onAppDetach,
      onExitRequested: _onExitRequested,
      onStateChange: _onStateChanged,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _onAppDetach() {
    print('App lifecycle: App detached, forcing cleanup...');
    GlobalMinerManager.cleanup();
  }

  Future<AppExitResponse> _onExitRequested() async {
    print('App lifecycle: Exit requested, cleaning up processes...');

    try {
      await GlobalMinerManager.cleanup();
      print('App lifecycle: Cleanup completed, allowing exit');
      return AppExitResponse.exit;
    } catch (e) {
      print('App lifecycle: Error during cleanup: $e');
      // Still allow exit even if cleanup fails
      return AppExitResponse.exit;
    }
  }

  void _onStateChanged(AppLifecycleState state) {
    print('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      print('App lifecycle: App backgrounded/detached, cleaning up...');
      GlobalMinerManager.cleanup();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Quantus Miner',
    theme: ThemeData.dark(useMaterial3: true),
    routerConfig: _router,
  );
}
