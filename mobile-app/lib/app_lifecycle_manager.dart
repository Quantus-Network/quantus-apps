import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/services/history_polling_manager.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

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
            quantusDebugPrint('Back online - resuming polling');
            pollingManager.resumePolling();
            pollingManager.triggerSilentRefresh();
          } else if (status == NetworkStatus.offline) {
            quantusDebugPrint('Gone offline - pausing polling');
            pollingManager.pausePolling();
          }
        },
        loading: () {},
        error: (e, _) {
          quantusDebugPrint('Error listening to network status: $e');
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
        quantusDebugPrint('AppLifecycleState.resumed - resuming from background');
        _isBackgrounded = false;

        // Only resume polling if online
        if (isOnline) {
          pollingManager.resumePolling();
          pollingManager.triggerSilentRefresh();
        } else {
          quantusDebugPrint('App resumed but offline - polling paused');
        }

        // Check authentication ONLY on resume from background.
        // This prevents flicker from transient backgrounds (FaceID, system overlays)
        // that briefly pause/resume the app.
        localAuthNotifier.checkAuthentication();

        // Initialize Taskmaster login if wallet exists
        _initializeTaskmasterLogin();

        // Sync remote config on background resume
        unawaited(ref.read(remoteConfigProvider.notifier).syncConfig());
      }
    } else {
      // Handle background states (inactive, paused, hidden, detached)
      // Skip if the biometric dialog caused this lifecycle change — on some
      // Android devices the prompt triggers inactive→resumed oscillation.
      if (!_isBackgrounded && !ref.read(localAuthProvider).isAuthenticating) {
        quantusDebugPrint('AppLifecycleState.$state - pausing (update pause time only)');
        _isBackgrounded = true;

        pollingManager.pausePolling();
        localAuthNotifier.recordBackgroundTime();
      } else {
        quantusDebugPrint('AppLifecycleState.$state - already backgrounded, skipping actions');
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
        quantusDebugPrint('Taskmaster login initialized');
      }
    } catch (e) {
      quantusDebugPrint('Failed to initialize taskmaster login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
