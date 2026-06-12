import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/pending_transaction_reconciliation_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Service that handles global history polling - refreshes transaction history
/// every minute to keep the UI up to date with the latest blockchain state.
class GlobalHistoryPollingService {
  final Ref _ref;
  Timer? _pollingTimer;
  bool _isPolling = false;

  GlobalHistoryPollingService(this._ref);

  /// Starts the global history polling.
  /// This should be called when the app starts and accounts are available.
  void startPolling() {
    if (_isPolling) return;

    _isPolling = true;
    _scheduleNextPoll();
    quantusDebugPrint('Global history polling started');
  }

  /// Stops the global history polling.
  /// This should be called when the app is disposed or user logs out.
  void stopPolling() {
    if (!_isPolling && _pollingTimer == null) {
      return;
    }
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    quantusDebugPrint('Global history polling stopped');
  }

  /// Pauses polling temporarily (e.g., when app goes to background)
  void pausePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    quantusDebugPrint('Global history polling paused');
  }

  /// Resumes polling if it was previously started
  void resumePolling() {
    if (_isPolling && _pollingTimer == null) {
      _scheduleNextPoll();
      quantusDebugPrint('Global history polling resumed');
    }
  }

  void _scheduleNextPoll() {
    _pollingTimer?.cancel();

    _pollingTimer = Timer(const Duration(minutes: 1), () {
      _performPoll();
    });
  }

  Future<void> _performPoll() async {
    if (!_isPolling) return;

    // Check connectivity before polling
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      quantusDebugPrint('Skipping poll - offline');
      _scheduleNextPoll();
      return;
    }

    try {
      quantusDebugPrint('Performing global history poll for active account...');

      invalidateActiveAccountBalance(_ref);
      await silentRefreshActiveAccount(_ref);
      invalidateActiveMultisigProposals(_ref);

      // Reconcile pending transactions with confirmed transactions
      await _ref.read(pendingTransactionReconciliationServiceProvider).reconcilePendingTransactions();

      quantusDebugPrint('Global history poll completed');
    } catch (e) {
      quantusDebugPrint('Error during global history poll: $e');
    } finally {
      // Schedule the next poll regardless of success/failure
      if (_isPolling) {
        _scheduleNextPoll();
      }
    }
  }

  /// Manually trigger a history refresh (useful for pull-to-refresh)
  Future<void> triggerManualRefresh() async {
    quantusDebugPrint('Global polling manager: Manual Refresh!');

    // Check connectivity before refreshing
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      quantusDebugPrint('Skipping manual refresh - offline');
      return;
    }

    final active = _ref.read(activeAccountProvider).value;
    if (active != null) {
      invalidateActiveAccountBalance(_ref);
      await Future.wait([
        _ref.read(balanceProviderFamily(active.account.accountId).future),
        refreshAccountsPagination(
          _ref,
          accountIds: [active.account.accountId],
          action: (notifier) => notifier.loadingRefresh(),
        ),
      ]);
    }

    await refreshActiveMultisigProposals(_ref);

    // Also reconcile pending transactions during manual refresh
    await _ref.read(pendingTransactionReconciliationServiceProvider).reconcilePendingTransactions();
  }

  void dispose() {
    stopPolling();
  }
}

/// Provider for the global history polling service
final globalHistoryPollingServiceProvider = Provider<GlobalHistoryPollingService>((ref) {
  final service = GlobalHistoryPollingService(ref);

  // Automatically start polling when accounts become available
  ref.listen(accountsProvider, (previous, next) {
    next.when(
      data: (accounts) {
        if (accounts.isNotEmpty) {
          service.startPolling();
        } else {
          service.stopPolling();
        }
      },
      loading: () {},
      error: (e, st) {
        quantusDebugPrint('Error in account stats polling service: stopping polling');
        TelemetryService().sendError(
          'GlobalHistoryPollingService Error in accountsProvider: stopping polling',
          error: e,
          stackTrace: st,
        );
        service.stopPolling();
      },
    );
  });

  ref.listen(activeAccountProvider, (previous, next) {
    final previousId = previous?.value?.account.accountId;
    final nextId = next.value?.account.accountId;
    if (nextId == null || previousId == null || previousId == nextId) return;

    refreshActiveAccountOnSwitch(ref);
  });

  // Clean up when provider is disposed
  ref.onDispose(() => service.dispose());

  return service;
});
