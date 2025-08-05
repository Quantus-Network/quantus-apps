import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        // Resume polling when app comes back to foreground
        pollingManager.resumePolling();
        // Trigger a silent refresh to catch up on any missed updates
        pollingManager.triggerSilentRefresh();
        break;

      case AppLifecycleState.detached:
        // App is being terminated
        pollingManager.stopPolling();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
