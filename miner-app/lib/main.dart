import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:ui';

import 'features/setup/node_setup_screen.dart';
import 'features/setup/node_identity_setup_screen.dart';
import 'features/setup/rewards_address_setup_screen.dart';
import 'features/miner/miner_dashboard_screen.dart';
import 'features/withdrawal/withdrawal_screen.dart';
import 'src/services/binary_manager.dart';
import 'src/services/miner_wallet_service.dart';
import 'src/services/mining_orchestrator.dart';
import 'src/services/process_cleanup_service.dart';
import 'src/utils/app_logger.dart';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:telemetrydecksdk/telemetrydecksdk.dart';

final _log = log.withTag('App');

/// Global class to manage mining orchestrator lifecycle.
///
/// This is used for cleanup during app exit/detach events.
class GlobalMinerManager {
  static MiningOrchestrator? _orchestrator;

  /// Register the active orchestrator for lifecycle management.
  static void setOrchestrator(MiningOrchestrator? orchestrator) {
    _orchestrator = orchestrator;
    _log.d('Orchestrator registered: ${orchestrator != null}');
  }

  /// Get the current orchestrator, if any.
  static MiningOrchestrator? getOrchestrator() {
    return _orchestrator;
  }

  /// Synchronous force stop for app detach scenarios.
  ///
  /// This is called from _onAppDetach which cannot be async.
  /// It fires off process kills without waiting for completion.
  static void forceStopAll() {
    _log.i('Force stopping all processes (sync)...');
    if (_orchestrator != null) {
      try {
        _orchestrator!.forceStop();
        _orchestrator = null;
      } catch (e) {
        _log.e('Error force stopping orchestrator', error: e);
      }
    }

    // Fire and forget - kill any remaining quantus processes
    ProcessCleanupService.killAllQuantusProcesses();
  }

  /// Cleanup all mining processes.
  ///
  /// Called during app exit (async context).
  static Future<void> cleanup() async {
    _log.i('Starting global cleanup...');
    if (_orchestrator != null) {
      try {
        _orchestrator!.forceStop();
        _orchestrator = null;
      } catch (e) {
        _log.e('Error stopping orchestrator', error: e);
      }
    }

    // Kill any remaining quantus processes using the cleanup service
    await ProcessCleanupService.killAllQuantusProcesses();
  }
}

Future<String?> initialRedirect(BuildContext context, GoRouterState state) async {
  final currentRoute = state.uri.toString();

  // Don't redirect if already on a sub-route (like /withdraw)
  if (currentRoute == '/withdraw') {
    return null;
  }

  // Check 1: Node Installed
  bool isNodeInstalled = false;
  try {
    isNodeInstalled = await BinaryManager.hasBinary();
  } catch (e) {
    _log.e('Error checking node installation', error: e);
    isNodeInstalled = false;
  }

  if (!isNodeInstalled) {
    _log.d('Node not installed, redirecting to setup');
    return (currentRoute == '/node_setup') ? null : '/node_setup';
  }

  // Check 2: Node Identity Set
  bool isIdentitySet = false;
  try {
    final identityPath = '${await BinaryManager.getQuantusHomeDirectoryPath()}/node_key.p2p';
    isIdentitySet = await File(identityPath).exists();
  } catch (e) {
    _log.e('Error checking node identity', error: e);
    isIdentitySet = false;
  }

  if (!isIdentitySet) {
    return (currentRoute == '/node_identity_setup') ? null : '/node_identity_setup';
  }

  // Check 3: Rewards Wallet Set (mnemonic-based wormhole address)
  bool isRewardsWalletSet = false;
  try {
    final walletService = MinerWalletService();
    isRewardsWalletSet = await walletService.isSetupComplete();
  } catch (e) {
    _log.e('Error checking rewards wallet', error: e);
    isRewardsWalletSet = false;
  }

  if (!isRewardsWalletSet) {
    return (currentRoute == '/rewards_address_setup') ? null : '/rewards_address_setup';
  }

  // If all setup steps are complete, go to the miner dashboard
  return (currentRoute == '/miner_dashboard') ? null : '/miner_dashboard';
}

final _router = GoRouter(
  initialLocation: '/',
  redirect: initialRedirect,
  routes: [
    GoRoute(
      path: '/',
      // Builder is not strictly necessary if initialLocation and redirect handle it,
      // but can be a fallback or initial loading screen.
      builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
    GoRoute(path: '/node_setup', builder: (context, state) => const NodeSetupScreen()),
    GoRoute(path: '/node_identity_setup', builder: (context, state) => const NodeIdentitySetupScreen()),
    GoRoute(path: '/rewards_address_setup', builder: (context, state) => const RewardsAddressSetupScreen()),
    GoRoute(path: '/miner_dashboard', builder: (context, state) => const MinerDashboardScreen()),
    GoRoute(
      path: '/withdraw',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return WithdrawalScreen(wormholeAddress: extra?['address'] as String?);
      },
    ),
  ],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter bindings are initialized

  // Note: Startup cleanup removed for simplicity

  try {
    await QuantusSdk.init();
    _log.i('SDK initialized');
  } catch (e) {
    _log.e('Error initializing SDK', error: e);
  }

  Telemetrydecksdk.start(
    const TelemetryManagerConfiguration(appID: '22C2FABE-0070-4BCA-B774-AB4380607EB2', salt: 'QDay'),
  );

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
    _log.i('App detached, cleaning up...');
    // Use synchronous force stop since _onAppDetach cannot be async
    GlobalMinerManager.forceStopAll();
  }

  Future<AppExitResponse> _onExitRequested() async {
    _log.i('Exit requested, cleaning up...');

    try {
      await GlobalMinerManager.cleanup();
      return AppExitResponse.exit;
    } catch (e) {
      _log.e('Error during exit cleanup', error: e);
      // Still allow exit even if cleanup fails
      return AppExitResponse.exit;
    }
  }

  void _onStateChanged(AppLifecycleState state) {
    _log.d('Lifecycle state: $state');
    // Note: We intentionally do NOT cleanup on pause/background
    // Mining should continue when the app is backgrounded
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(title: 'Quantus Miner', theme: ThemeData.dark(useMaterial3: true), routerConfig: _router);
}
