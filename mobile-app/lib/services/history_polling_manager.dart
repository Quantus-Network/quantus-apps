import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/global_history_polling_service.dart';
import 'package:resonance_network_wallet/services/reversible_transfer_monitoring_service.dart';
import 'package:resonance_network_wallet/services/transaction_tracking_service.dart';

/// Manager that coordinates all polling services: global history, transaction
/// tracking,
/// and reversible transfer monitoring. This ensures all services are
/// properly initialized and managed together.
class HistoryPollingManager {
  final Ref _ref;
  late final GlobalHistoryPollingService _globalPoller;
  late final TransactionTrackingService _transactionTracker;
  late final ReversibleTransferMonitoringService _reversibleMonitor;

  HistoryPollingManager(this._ref) {
    _globalPoller = _ref.read(globalHistoryPollingServiceProvider);
    _transactionTracker = _ref.read(transactionTrackingServiceProvider);
    _reversibleMonitor = _ref.read(reversibleTransferMonitoringServiceProvider);
  }

  /// Initialize all polling services.
  /// This should be called early in the app lifecycle.
  void initialize() {
    print('Initializing history polling manager...');
    _globalPoller;
    _transactionTracker;
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

    await _globalPoller.triggerManualRefresh();
    await _transactionTracker.forceCheckAllTrackedTransactions();
    await _reversibleMonitor.forceCheckAllMonitoredTransfers();
  }

  void dispose() {
    _globalPoller.dispose();
    _transactionTracker.dispose();
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
