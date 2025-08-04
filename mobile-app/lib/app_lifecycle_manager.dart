import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/history_polling_manager.dart';

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final pollingManager = ref.read(historyPollingManagerProvider);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
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

      case AppLifecycleState.hidden:
        // App is hidden but still running
        pollingManager.pausePolling();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Usage example for your main app:
/// 
/// ```dart
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return ProviderScope(
///       child: AppInitializer(
///         child: AppLifecycleManager(
///           child: MaterialApp(
///             // Your app content here
///           ),
///         ),
///       ),
///     );
///   }
/// }
/// ```