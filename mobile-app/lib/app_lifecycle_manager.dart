import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/history_polling_manager.dart';

/// Provider that holds the current app lifecycle state
final appLifecycleStateProvider = StateProvider<AppLifecycleState>(
  (ref) => AppLifecycleState.resumed,
);

/// App lifecycle listener that manages polling based on app state
class AppLifecycleManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleManager({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleManager> createState() =>
      _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends ConsumerState<AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set initial state
    ref.read(appLifecycleStateProvider.notifier).state =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    
    // Initialize Taskmaster login on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTaskmasterLogin();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleStateProvider.notifier).state = state;

    final pollingManager = ref.read(historyPollingManagerProvider);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Pause global polling when app goes to background
        // Transaction tracking continues for pending transactions
        pollingManager.pausePolling();
        break;

      case AppLifecycleState.resumed:
        print('AppLifecycleState.resumed');
        // Resume polling when app comes back to foreground
        pollingManager.resumePolling();
        // Trigger a silent refresh to catch up on any missed updates
        pollingManager.triggerSilentRefresh();
        // Initialize Taskmaster login if wallet exists
        _initializeTaskmasterLogin();
        break;

      case AppLifecycleState.detached:
        // App is being terminated
        pollingManager.stopPolling();
        break;
    }
  }

  // This is merely an optimization - check our login is active. 
  Future<void> _initializeTaskmasterLogin() async {
    try {
      final settingsService = SettingsService();
      final hasWallet = await settingsService.getHasWallet();
      
      if (hasWallet) {
        final taskmasterService = TaskmasterService();
        await taskmasterService.ensureIsLoggedIn();
        print('Taskmaster login initialized');
      }
    } catch (e) {
      print('Failed to initialize taskmaster login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
