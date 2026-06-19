import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/global_history_polling_service.dart';
import 'package:resonance_network_wallet/services/reversible_transfer_monitoring_service.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Manager that coordinates all polling services: global history, transaction
/// tracking,
/// and reversible transfer monitoring. This ensures all services are
/// properly initialized and managed together.
class HistoryPollingManager {
  final Ref _ref;
  late final GlobalHistoryPollingService _globalPoller;
  late final ReversibleTransferMonitoringService _reversibleMonitor;
  bool _initialized = false;
  bool _isRefreshing = false;

  HistoryPollingManager(this._ref) {
    _globalPoller = _ref.read(globalHistoryPollingServiceProvider);
    _reversibleMonitor = _ref.read(reversibleTransferMonitoringServiceProvider);
  }

  /// Initialize all polling services.
  /// This should be called early in the app lifecycle.
  void initialize() {
    quantusDebugPrint('Initializing history polling manager...');
    if (_initialized) return;
    _globalPoller;
    _reversibleMonitor;
    quantusDebugPrint('History polling manager initialized');
    _initialized = true;
  }

  /// Pause all polling (useful when app goes to background)
  void pausePolling() {
    _globalPoller.pausePolling();
  }

  void resumePolling() {
    _globalPoller.resumePolling();
  }

  void stopPolling() {
    _globalPoller.stopPolling();
  }

  /// Trigger a silent refresh of all data (no loading indicators).
  ///
  /// Invalidating providers only schedules a reload; it does not wait for it.
  /// To avoid flipping [_isRefreshing] back to false while balance, history, and
  /// multisig providers are still re-fetching, this awaits each reload to
  /// completion so concurrent triggers are correctly suppressed.
  Future<void> triggerSilentRefresh() async {
    if (_isRefreshing) {
      quantusDebugPrint('History polling manager: refresh in progress, skipping');
      return;
    }

    _isRefreshing = true;
    try {
      quantusDebugPrint('History polling manager: Silent Refresh!');

      await Future.wait([
        refreshActiveAccountBalance(_ref),
        silentRefreshActiveAccount(_ref),
        refreshActiveMultisigProposals(_ref),
      ]);
    } finally {
      _isRefreshing = false;
    }
  }

  void dispose() {
    _globalPoller.dispose();
    _reversibleMonitor.dispose();
  }
}

/// Provider for the history polling manager
final historyPollingManagerProvider = Provider<HistoryPollingManager>((ref) {
  final manager = HistoryPollingManager(ref);

  // Initialize immediately
  manager.initialize();

  // Clean up when provider is disposed
  ref.onDispose(() => manager.dispose());

  return manager;
});
