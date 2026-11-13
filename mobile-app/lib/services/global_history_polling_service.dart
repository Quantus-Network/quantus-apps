import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/pending_transaction_reconciliation_service.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Service that handles global history polling - refreshes transaction history
/// every minute to keep the UI up to date with the latest blockchain state.
///
/// While the active encrypted account has change on the way, polls come
/// faster — [pendingPollInterval], doubling up to [pollInterval] — so the
/// change becomes spendable soon after the indexer sees it rather than at the
/// next minute mark. A new send resets the cadence.
class GlobalHistoryPollingService {
  static const Duration pollInterval = Duration(minutes: 1);
  static const Duration pendingPollInterval = Duration(seconds: 15);

  final Ref _ref;
  Timer? _pollingTimer;
  bool _isPolling = false;
  int _pollsWhilePending = 0;
  BigInt _lastPending = BigInt.zero;

  GlobalHistoryPollingService(this._ref);

  /// Delay before the next poll given the active account's pending change
  /// and how many polls have already run waiting for it.
  static Duration pollDelay({required BigInt pending, required int pollsWhilePending}) {
    if (pending <= BigInt.zero) return pollInterval;
    var delay = pendingPollInterval;
    for (var i = 0; i < pollsWhilePending && delay < pollInterval; i++) {
      delay *= 2;
    }
    return delay < pollInterval ? delay : pollInterval;
  }

  /// Called whenever the active account's pending change changes. A different
  /// amount means a send was just submitted (or change arrived), so the
  /// cadence restarts from [pendingPollInterval] — or back to [pollInterval]
  /// when nothing is pending any more.
  void pendingChangeUpdated(BigInt pending) {
    if (pending == _lastPending) return;
    _lastPending = pending;
    _pollsWhilePending = 0;
    if (_isPolling && _pollingTimer != null) {
      _scheduleNextPoll();
    }
  }

  /// Starts the global history polling.
  /// This should be called when the app starts and accounts are available.
  void startPolling() {
    if (_isPolling) return;

    _isPolling = true;
    _scheduleNextPoll();
    quantusPrint('Global history polling started');
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
    quantusPrint('Global history polling stopped');
  }

  /// Pauses polling temporarily (e.g., when app goes to background)
  void pausePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    quantusPrint('Global history polling paused');
  }

  /// Resumes polling if it was previously started
  void resumePolling() {
    if (_isPolling && _pollingTimer == null) {
      _scheduleNextPoll();
      quantusPrint('Global history polling resumed');
    }
  }

  void _scheduleNextPoll() {
    _pollingTimer?.cancel();

    final delay = pollDelay(pending: _lastPending, pollsWhilePending: _pollsWhilePending);
    _pollingTimer = Timer(delay, () {
      _performPoll();
    });
  }

  Future<void> _performPoll() async {
    if (!_isPolling) return;
    if (_lastPending > BigInt.zero) _pollsWhilePending++;

    // Check connectivity before polling
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      quantusPrint('Skipping poll - offline');
      _scheduleNextPoll();
      return;
    }

    try {
      quantusPrint('Performing global history poll for active account...');

      invalidateActiveAccountBalance(_ref);
      await silentRefreshActiveAccount(_ref);
      invalidateActiveMultisigProposals(_ref);

      // Reconcile pending transactions with confirmed transactions
      await _ref.read(pendingTransactionReconciliationServiceProvider).reconcilePendingTransactions();

      quantusPrint('Global history poll completed');
    } catch (e) {
      quantusPrint('Error during global history poll: $e');
    } finally {
      // Schedule the next poll regardless of success/failure
      if (_isPolling) {
        _scheduleNextPoll();
      }
    }
  }

  /// Manually trigger a history refresh (useful for pull-to-refresh)
  Future<void> triggerManualRefresh() async {
    quantusPrint('Global polling manager: Manual Refresh!');

    // Check connectivity before refreshing
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      quantusPrint('Skipping manual refresh - offline');
      return;
    }

    if (activeAccountId(_ref) != null) {
      // Use the shared helper so encrypted accounts reload wormhole UTXO state
      // (not the transparent balanceProviderFamily, which is irrelevant for
      // them). Pull-to-refresh is the one place a full rescan is asked for.
      final paginatedId = activePaginatedAccountId(_ref);
      await Future.wait([
        refreshActiveAccountBalance(_ref, discardCaches: true),
        if (paginatedId != null)
          refreshAccountsPagination(_ref, accountIds: [paginatedId], action: (notifier) => notifier.loadingRefresh()),
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
      error: (e, _) {
        quantusPrint('Error in account stats polling service: stopping polling');
        ref
            .read(telemetryProvider)
            .sendError('GlobalHistoryPollingService Error in accountsProvider: stopping polling', error: e);
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

  ref.listen(
    activeEncryptedPendingProvider,
    (_, pending) => service.pendingChangeUpdated(pending),
    fireImmediately: true,
  );

  // Clean up when provider is disposed
  ref.onDispose(() => service.dispose());

  return service;
});
