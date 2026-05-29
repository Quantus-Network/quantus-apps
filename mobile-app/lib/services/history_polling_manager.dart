import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
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

  /// Trigger a manual refresh of all data // This is not called from anywhere!
  Future<void> triggerManualRefresh() async {
    quantusDebugPrint('History polling manager: Manual Refresh!');

    // Refresh balance (with loading indicators)
    _refreshBalance(showLoading: true);

    await _globalPoller.triggerManualRefresh();
  }

  /// Trigger a silent refresh of all data (no loading indicators)
  Future<void> triggerSilentRefresh() async {
    quantusDebugPrint('History polling manager: Silent Refresh!');

    _refreshBalance(showLoading: false);
    await silentRefreshActiveAccount(_ref);
  }

  /// Helper method to refresh balance with or without loading indicators
  void _refreshBalance({required bool showLoading}) {
    if (showLoading) {
      invalidateActiveAccountBalance(_ref);
      _ref.invalidate(balanceProviderRaw);
    } else {
      invalidateActiveAccountBalance(_ref);
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
