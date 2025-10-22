import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/connectivity_service.dart';
import 'package:resonance_network_wallet/services/pending_transaction_reconciliation_service.dart';

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
    print('Global history polling started');
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
    print('Global history polling stopped');
  }

  /// Pauses polling temporarily (e.g., when app goes to background)
  void pausePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    print('Global history polling paused');
  }

  /// Resumes polling if it was previously started
  void resumePolling() {
    if (_isPolling && _pollingTimer == null) {
      _scheduleNextPoll();
      print('Global history polling resumed');
    }
  }

  void _scheduleNextPoll() {
    _pollingTimer = Timer(const Duration(minutes: 1), () {
      _performPoll();
    });
  }

  Future<void> _performPoll() async {
    if (!_isPolling) return;

    // Check connectivity before polling
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      print('Skipping poll - offline');
      _scheduleNextPoll();
      return;
    }

    try {
      // Check if we have accounts available
      final accountsState = _ref.read(accountsProvider);
      if (accountsState.value?.isEmpty ?? true) {
        _scheduleNextPoll();
        return;
      }

      print('Performing global history poll...');

      // Refresh balance silently (transactions might have changed balance)
      _ref.invalidate(balanceProviderFamily);

      // Silently refresh without showing loading indicators for global
      // and active filtered
      await _ref.read(paginationControllerProvider.notifier).silentRefresh();
      final active = _ref.read(activeAccountProvider).value;
      if (active != null) {
        await _ref
            .read(
              filteredPaginationControllerProviderFamily(
                AccountIdListCache.get([active.accountId]),
              ).notifier,
            )
            .silentRefresh();
      }

      // Reconcile pending transactions with confirmed transactions
      await _ref
          .read(pendingTransactionReconciliationServiceProvider)
          .reconcilePendingTransactions();

      print('Global history poll completed');
    } catch (e) {
      print('Error during global history poll: $e');
    } finally {
      // Schedule the next poll regardless of success/failure
      if (_isPolling) {
        _scheduleNextPoll();
      }
    }
  }

  /// Manually trigger a history refresh (useful for pull-to-refresh)
  Future<void> triggerManualRefresh() async {
    print('Global polling manager: Manual Refresh!');
    
    // Check connectivity before refreshing
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      print('Skipping manual refresh - offline');
      return;
    }
    
    await _ref.read(paginationControllerProvider.notifier).loadingRefresh();
    final active = _ref.read(activeAccountProvider).value;
    if (active != null) {
      await _ref
          .read(
            filteredPaginationControllerProviderFamily(
              AccountIdListCache.get([active.accountId]),
            ).notifier,
          )
          .loadingRefresh();
    }

    // Also reconcile pending transactions during manual refresh
    await _ref
        .read(pendingTransactionReconciliationServiceProvider)
        .reconcilePendingTransactions();
  }

  void dispose() {
    stopPolling();
  }
}

/// Provider for the global history polling service
final globalHistoryPollingServiceProvider =
    Provider<GlobalHistoryPollingService>((ref) {
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
          loading: () => service.stopPolling(),
          error: (_, _) => service.stopPolling(),
        );
      });

      // Clean up when provider is disposed
      ref.onDispose(() => service.dispose());

      return service;
    });
