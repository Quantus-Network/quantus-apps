import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/services/history_polling_manager.dart';

/// Provider that holds the current app lifecycle state
final appLifecycleStateProvider = StateProvider<AppLifecycleState>((ref) => AppLifecycleState.resumed);

/// App lifecycle listener that manages polling based on app state
class AppLifecycleManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleManager({super.key, required this.child});

  @override
  ConsumerState<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends ConsumerState<AppLifecycleManager> with WidgetsBindingObserver {
  // Track if we have already performed background/pause actions to avoid duplicates
  // as the OS can cycle through multiple states (inactive -> hidden -> paused)
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize background state
    final currentState = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _isBackgrounded = currentState != AppLifecycleState.resumed;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final localAuthNotifier = ref.read(localAuthProvider.notifier);
      ref.read(appLifecycleStateProvider.notifier).state =
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

      _initializeTaskmasterLogin();
      _setupConnectivityListener();
      localAuthNotifier.checkAuthentication();
    });
  }

  void _setupConnectivityListener() {
    ref.listenManual(networkStatusProvider, (previous, next) {
      next.when(
        data: (status) {
          final pollingManager = ref.read(historyPollingManagerProvider);
          final appState = ref.read(appLifecycleStateProvider);

          if (status == NetworkStatus.online && appState == AppLifecycleState.resumed) {
            print('Back online - resuming polling');
            pollingManager.resumePolling();
            pollingManager.triggerSilentRefresh();
          } else if (status == NetworkStatus.offline) {
            print('Gone offline - pausing polling');
            pollingManager.pausePolling();
          }
        },
        loading: () {},
        error: (e, _) {
          print('Error listening to network status: $e');
        },
      );
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
    final localAuthNotifier = ref.read(localAuthProvider.notifier);
    final pollingManager = ref.read(historyPollingManagerProvider);
    final isOnline = ref.read(isOnlineProvider);

    if (state == AppLifecycleState.resumed) {
      // Only resume if we were previously backgrounded
      if (_isBackgrounded) {
        print('AppLifecycleState.resumed - resuming from background');
        _isBackgrounded = false;

        // Only resume polling if online
        if (isOnline) {
          pollingManager.resumePolling();
          pollingManager.triggerSilentRefresh();
        } else {
          print('App resumed but offline - polling paused');
        }

        // Always check authentication on resume to enforce inactivity timeout
        localAuthNotifier.checkAuthentication();

        // Initialize Taskmaster login if wallet exists
        _initializeTaskmasterLogin();
      }
    } else {
      // Handle background states (inactive, paused, hidden, detached)
      // Only act if we haven't already processed a background transition
      if (!_isBackgrounded) {
        print('AppLifecycleState.$state - pausing and locking');
        _isBackgrounded = true;

        // Pause global polling when app goes to background
        // Transaction tracking continues for pending transactions
        pollingManager.pausePolling();

        // When the app goes into the background, lock it.
        localAuthNotifier.lockApp();
      } else {
        print('AppLifecycleState.$state - already backgrounded, skipping actions');
      }
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
