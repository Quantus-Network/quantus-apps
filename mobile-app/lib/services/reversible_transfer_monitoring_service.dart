import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/app_lifecycle_manager.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_cancellations_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/tx_filter_family_provider.dart';

/// Service that monitors reversible transfers approaching execution time
/// and polls the chain aggressively when timers hit zero to catch state
/// changes quickly
class ReversibleTransferMonitoringService {
  final Ref _ref;
  final Map<String, Timer> _timers = {};
  final Map<String, Timer> _executionPollers = {};
  ProviderSubscription? _txSubscription;

  static const Duration _pollInterval = Duration(seconds: 5); // Aggressive polling

  ReversibleTransferMonitoringService(this._ref) {
    _ref.listen(appLifecycleStateProvider, (previous, next) {
      if (next == AppLifecycleState.resumed) {
        _listenToTransactions();
      } else {
        dispose();
      }
    });

    if (_ref.read(appLifecycleStateProvider) == AppLifecycleState.resumed) {
      _listenToTransactions();
    }
  }

  /// Public API to immediately start execution/cancellation polling for a
  /// specific reversible transfer. This reuses the same aggressive polling
  /// logic used when the timer hits zero.
  void startImmediatePollingForTransfer(ReversibleTransferEvent transfer) {
    _startExecutionPolling(transfer);
  }

  void _listenToTransactions() {
    _txSubscription?.close();
    _txSubscription = _ref.listen(activeAccountPaginationProvider(TransactionFilter.all), (previous, current) {
      if (current == null) return;
      _handleTransactionsUpdate(current.scheduledReversibleTransfers);
    });
  }

  void _handleTransactionsUpdate(List<ReversibleTransferEvent> reversibleTransfers) {
    // Find scheduled transfers that need monitoring
    final scheduledReversibleTransfers = reversibleTransfers
        .where((tx) => tx.status == ReversibleTransferStatus.SCHEDULED)
        .toList();

    if (scheduledReversibleTransfers.isNotEmpty) {
      quantusDebugPrint(
        // ignore: lines_longer_than_80_chars
        'monitoring setvice: watching ${scheduledReversibleTransfers.length} reversible transfers!',
      );
    }

    // Start monitoring transfers approaching execution
    for (final transfer in scheduledReversibleTransfers) {
      // If we're not already monitoring this transfer
      if (!_timers.containsKey(transfer.id)) {
        _scheduleExecutionPolling(transfer);
      }
    }

    // Stop monitoring transfers that are no longer scheduled
    final currentIds = scheduledReversibleTransfers.map((tx) => tx.id).toSet();
    final timersToRemove = _timers.keys.where((id) => !currentIds.contains(id)).toList();

    for (final id in timersToRemove) {
      _stopMonitoringTransfer(id);
    }
  }

  void _scheduleExecutionPolling(ReversibleTransferEvent transfer) {
    final remainingTime = transfer.remainingTime;

    quantusDebugPrint(
      'Scheduling execution poll for ${transfer.id} '
      'in $remainingTime',
    );

    if (remainingTime <= Duration.zero) {
      // If time is already up, start polling immediately
      _startExecutionPolling(transfer);
    } else {
      // Set a timer for when the remaining time is up
      final timer = Timer(remainingTime, () {
        _startExecutionPolling(transfer);
        _timers.remove(transfer.id); // Timer has fired, remove it
      });
      _timers[transfer.id] = timer;
    }
  }

  void _startExecutionPolling(ReversibleTransferEvent transfer) {
    if (_executionPollers.containsKey(transfer.id)) {
      return; // Already polling
    }
    quantusDebugPrint('Starting execution polling for: ${transfer.id}');

    // Create aggressive polling timer
    final poller = Timer.periodic(_pollInterval, (_) {
      _checkForExecution(transfer);
    });

    _executionPollers[transfer.id] = poller;

    // Check immediately
    _checkForExecution(transfer);
  }

  Future<void> _checkForExecution(ReversibleTransferEvent transfer) async {
    // Check connectivity before polling
    final isOnline = _ref.read(isOnlineProvider);
    if (!isOnline) {
      quantusDebugPrint('Skipping execution check - offline');
      return;
    }

    try {
      quantusDebugPrint('polling execution on ${transfer.txId}');
      final historyService = _ref.read(chainHistoryServiceProvider);

      // Check if this specific transaction was executed using its txId
      // ignore: lines_longer_than_80_chars
      final transaction = await historyService.fetchExecutedTransactionByTxId(txId: transfer.txId);

      if (transaction != null) {
        quantusDebugPrint('Reversible transfer finished: ${transfer.id} ${transaction.status}');

        // Stop polling for this transfer
        _stopExecutionPolling(transfer.id);

        // Update filtered controllers for affected accounts so
        // active-account views reflect the change immediately
        final affectedAccounts = <String>{transfer.from, transfer.to};
        for (final accountId in affectedAccounts) {
          updatePaginationFiltersFor(_ref.read, [accountId], (notifier, _) {
            notifier.updateReversibleTransferToExecuted(transfer.txId, transaction.status);
          });
        }

        invalidateAccountBalances(_ref, affectedAccounts);

        _ref.read(pendingCancellationsProvider.notifier).removePendingCancellation(transfer.id);

        quantusDebugPrint('Updated transfer status inline - moved to done list');
      }
    } catch (e) {
      quantusDebugPrint('Error checking for transfer execution: $e');
      // Continue polling despite errors
    }
  }

  void _stopExecutionPolling(String transferId) {
    final poller = _executionPollers.remove(transferId);
    poller?.cancel();
    quantusDebugPrint('Stopped execution polling for: $transferId');
  }

  void _stopMonitoringTransfer(String transferId) {
    final timer = _timers.remove(transferId);
    timer?.cancel();
    _stopExecutionPolling(transferId);
    quantusDebugPrint('Stopped monitoring transfer: $transferId');
  }

  /// Manually trigger a check for all monitored transfers (useful for testing)
  Future<void> forceCheckAllMonitoredTransfers() async {
    if (_executionPollers.isNotEmpty) {
      await silentRefreshActiveAccount(_ref);
    }
  }

  void dispose() {
    // Cancel all timers and pollers
    for (final timer in _timers.values) {
      timer.cancel();
    }
    for (final poller in _executionPollers.values) {
      poller.cancel();
    }

    _txSubscription?.close();
    _txSubscription = null;

    _timers.clear();
    _executionPollers.clear();
  }
}

/// Provider for the reversible transfer monitoring service
final reversibleTransferMonitoringServiceProvider = Provider<ReversibleTransferMonitoringService>((ref) {
  final service = ReversibleTransferMonitoringService(ref);

  // Clean up when provider is disposed
  ref.onDispose(service.dispose);

  return service;
});
