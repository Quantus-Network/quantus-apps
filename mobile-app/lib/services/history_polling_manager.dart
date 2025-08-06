import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/global_history_polling_service.dart';
import 'package:resonance_network_wallet/services/reversible_transfer_monitoring_service.dart';

/// Manager that coordinates all polling services: global history, transaction
/// tracking,
/// and reversible transfer monitoring. This ensures all services are
/// properly initialized and managed together.
class HistoryPollingManager {
  final Ref _ref;
  late final GlobalHistoryPollingService _globalPoller;
  late final ReversibleTransferMonitoringService _reversibleMonitor;

  HistoryPollingManager(this._ref) {
    _globalPoller = _ref.read(globalHistoryPollingServiceProvider);
    _reversibleMonitor = _ref.read(reversibleTransferMonitoringServiceProvider);
  }

  /// Initialize all polling services.
  /// This should be called early in the app lifecycle.
  void initialize() {
    print('Initializing history polling manager...');
    _globalPoller;
    _reversibleMonitor;
    print('History polling manager initialized');
  }

  /// Pause all polling (useful when app goes to background)
  void pausePolling() {
    _globalPoller.pausePolling();
    // Transaction tracker continues in background for pending transactions
  }

  /// Resume all polling (useful when app comes to foreground)
  void resumePolling() {
    _globalPoller.resumePolling();
    // Transaction tracker automatically resumes
  }

  /// Stop all polling (useful when user logs out)
  void stopPolling() {
    _globalPoller.stopPolling();
    // Transaction tracker automatically stops when no accounts
  }

  /// Trigger a manual refresh of all data
  Future<void> triggerManualRefresh() async {
    print('History polling manager: Manual Refresh!');

    // Refresh balance (with loading indicators)
    _refreshBalance(showLoading: true);

    await _globalPoller.triggerManualRefresh();
    await _reversibleMonitor.forceCheckAllMonitoredTransfers();
  }

  /// Trigger a silent refresh of all data (no loading indicators)
  Future<void> triggerSilentRefresh() async {
    print('History polling manager: Silent Refresh!');

    // Refresh balance silently (no loading indicators)
    _refreshBalance(showLoading: false);

    // Use silent refresh for background updates
    await _ref.read(paginationControllerProvider.notifier).silentRefresh();
    await _reversibleMonitor.forceCheckAllMonitoredTransfers();
  }

  /// Helper method to refresh balance with or without loading indicators
  void _refreshBalance({required bool showLoading}) {
    if (showLoading) {
      // For manual refresh - invalidate balance providers to show loading
      final activeAccount = _ref.read(activeAccountProvider).value;
      if (activeAccount != null) {
        _ref.invalidate(balanceProviderFamily);
      }
      _ref.invalidate(
        balanceProviderRaw,
      ); // Invalidate raw balance for loading state
      // balanceProvider (effective) will auto-update when raw balance changes
    } else {
      // For silent refresh - just invalidate family to refresh data silently
      _ref.invalidate(balanceProviderFamily);
      // balanceProvider (effective) will auto-update when raw balance changes
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
