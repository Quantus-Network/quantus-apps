import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/app_lifecycle_state_provider.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:wallet_core/services/history_polling_manager.dart';
import 'package:wallet_core/services/telemetry.dart';

/// Keeps what the open wallet shows current: the shared polling
/// ([HistoryPollingManager]) runs while the computer is online, and catches
/// up at once when it comes back.
///
/// Unlike the phone's, it keeps polling while the window is minimized or
/// hidden: what the wallet watches for, such as a send that never lands, is
/// noticed and notified then too. What only matters on screen still pauses
/// with a window no one can see ([appLifecycleStateProvider]).
class LiveDataScope extends ConsumerStatefulWidget {
  const LiveDataScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LiveDataScope> createState() => _LiveDataScopeState();
}

class _LiveDataScopeState extends ConsumerState<LiveDataScope> {
  late final HistoryPollingManager _polling;
  late final AppLifecycleListener _window;
  bool _isOnScreen = _onScreen(WidgetsBinding.instance.lifecycleState);
  bool _isOnline = true;
  bool _isPaused = false;

  /// Whether a window in [state] can be seen. Before the system has said, it
  /// is taken to be.
  static bool _onScreen(AppLifecycleState? state) => switch (state) {
    AppLifecycleState.hidden || AppLifecycleState.paused || AppLifecycleState.detached => false,
    AppLifecycleState.resumed || AppLifecycleState.inactive || null => true,
  };

  @override
  void initState() {
    super.initState();
    _polling = ref.read(historyPollingManagerProvider);
    _window = AppLifecycleListener(onStateChange: _onWindowChanged);
    ref.listenManual<bool>(isOnlineProvider, (_, isOnline) {
      _isOnline = isOnline;
      _update();
    }, fireImmediately: true);
    // A window that opens hidden says so once the first frame is built: no
    // provider may change while one is.
    if (!_isOnScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _publish(WidgetsBinding.instance.lifecycleState!);
      });
    }
  }

  @override
  void dispose() {
    _window.dispose();
    // The polling outlives this wallet, and a pause would outlast it too: the
    // next wallet's scope starts from polling that is not paused.
    if (_isPaused) _polling.resumePolling();
    super.dispose();
  }

  void _onWindowChanged(AppLifecycleState state) {
    _isOnScreen = _onScreen(state);
    _publish(state);
  }

  /// Tells what else pauses in the background ([appLifecycleStateProvider])
  /// whether the window is [state], a window on screen counting as in front.
  void _publish(AppLifecycleState state) {
    ref.read(appLifecycleStateProvider.notifier).state = _isOnScreen ? AppLifecycleState.resumed : state;
  }

  /// Pauses the polling when there is no network to poll, and resumes it,
  /// caught up, once there is.
  void _update() {
    if (_isOnline == !_isPaused) return;
    _isPaused = !_isOnline;
    if (_isPaused) {
      _polling.pausePolling();
      return;
    }
    _polling.resumePolling();
    unawaited(_reported(ref, _polling.triggerSilentRefresh(), 'Catching up as the wallet came back failed'));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Reads everything the open wallet shows again from the network, because
/// the person asked to (View › Refresh).
Future<void> refreshWallet(WidgetRef ref) {
  final refresh = _reported(
    ref,
    ref.read(historyPollingManagerProvider).triggerManualRefresh(),
    'The refresh asked for failed',
  );
  // Shown while it runs, as a light along the Activity panel's header.
  return ref.read(walletRefreshingProvider.notifier).track(refresh);
}

/// Waits for [refresh], reporting what makes it fail rather than raising it:
/// nothing waits on a refresh, and what it could not read is shown as
/// unavailable where it is drawn.
Future<void> _reported(WidgetRef ref, Future<void> refresh, String what) async {
  // Read now: by the time it fails, the widget [ref] belongs to may be gone.
  final telemetry = ref.read(telemetryProvider);
  try {
    await refresh;
  } catch (e) {
    quantusPrint('$what: $e');
    telemetry.sendError(what, error: e);
  }
}
