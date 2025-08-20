import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/app_lifecycle_manager.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Service that monitors reversible transfers approaching execution time
/// and polls the chain aggressively when timers hit zero to catch state
/// changes quickly
class ReversibleTransferMonitoringService {
  final Ref _ref;
  final Map<String, Timer> _timers = {};
  final Map<String, Timer> _executionPollers = {};

  static const Duration _pollInterval = Duration(
    seconds: 5,
  ); // Aggressive polling

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

  void _listenToTransactions() {
    _ref.listen(allTransactionsProvider, (previous, current) {
      current.when(
        data: (combinedData) {
          _handleTransactionsUpdate(combinedData.reversibleTransfers);
        },
        loading: () {},
        error: (_, _) {},
      );
    });
  }

  void _handleTransactionsUpdate(
    List<ReversibleTransferEvent> reversibleTransfers,
  ) {
    // Find scheduled transfers that need monitoring
    final scheduledTransfers = reversibleTransfers
        .where((tx) => tx.status == ReversibleTransferStatus.SCHEDULED)
        .toList();

    if (scheduledTransfers.isNotEmpty) {
      print(
        // ignore: lines_longer_than_80_chars
        'monitoring setvice: watching ${scheduledTransfers.length} reversible transfers!',
      );
    }

    // Start monitoring transfers approaching execution
    for (final transfer in scheduledTransfers) {
      // If we're not already monitoring this transfer
      if (!_timers.containsKey(transfer.id)) {
        _scheduleExecutionPolling(transfer);
      }
    }

    // Stop monitoring transfers that are no longer scheduled
    final currentIds = scheduledTransfers.map((tx) => tx.id).toSet();
    final timersToRemove = _timers.keys
        .where((id) => !currentIds.contains(id))
        .toList();

    for (final id in timersToRemove) {
      _stopMonitoringTransfer(id);
    }
  }

  void _scheduleExecutionPolling(ReversibleTransferEvent transfer) {
    final remainingTime = transfer.remainingTime;

    print(
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
    print('Starting execution polling for: ${transfer.id}');

    // Create aggressive polling timer
    final poller = Timer.periodic(_pollInterval, (_) {
      _checkForExecution(transfer);
    });

    _executionPollers[transfer.id] = poller;

    // Check immediately
    _checkForExecution(transfer);
  }

  Future<void> _checkForExecution(ReversibleTransferEvent transfer) async {
    try {
      // Use the new targeted query by transaction hash
      if (transfer.extrinsicHash == null) {
        print('unexpected null for extrinsic hash $transfer');
        return;
      }
      print('polling execution on ${transfer.extrinsicHash}');
      final historyService = _ref.read(chainHistoryServiceProvider);

      // Check if this specific transaction was executed using its hash
      // ignore: lines_longer_than_80_chars
      final transactions = await historyService
          .fetchTransactionsByTransactionHash(
            transactionHashes: [transfer.extrinsicHash!],
            limit: 5,
          );

      // Look for the executed version of this transfer
      final status = _checkIfTransferWasExecuted(transfer, transactions);

      if (status != null) {
        print('Reversible transfer finished: ${transfer.id} $status');

        // Stop polling for this transfer
        _stopExecutionPolling(transfer.id);

        // Update the transfer status inline - move from reversible
        // to executed list for both global and filtered controllers
        _ref
            .read(paginationControllerProvider.notifier)
            .updateReversibleTransferToExecuted(
              transfer.extrinsicHash!,
              status,
            );

        // Also update filtered controllers for affected accounts so
        // active-account views reflect the change immediately
        final affectedAccounts = <String>{transfer.from, transfer.to};
        for (final accountId in affectedAccounts) {
          _ref
              .read(
                filteredPaginationControllerProviderFamily(
                  AccountIdListCache.get([accountId]),
                ).notifier,
              )
              .updateReversibleTransferToExecuted(
                transfer.extrinsicHash!,
                status,
              );
        }

        // Refresh balance since transfer execution changes balance
        _ref.invalidate(balanceProviderFamily);

        print('Updated transfer status inline - moved to done list');
      }
    } catch (e) {
      print('Error checking for transfer execution: $e');
      // Continue polling despite errors
    }
  }

  ReversibleTransferStatus? _checkIfTransferWasExecuted(
    ReversibleTransferEvent originalTransfer,
    List<TransactionEvent> transactions,
  ) {
    // Look for a reversible transfer with same txId/extrinsicHash but EXECUTED status
    for (final historyTx in transactions) {
      if (historyTx is ReversibleTransferEvent) {
        final matchesHash =
            historyTx.extrinsicHash == originalTransfer.extrinsicHash;

        if (matchesHash &&
            historyTx.status != ReversibleTransferStatus.SCHEDULED) {
          print(
            'Found executed reversible transfer:'
            ' ${historyTx.id} (status: ${historyTx.status})',
          );
          return historyTx.status;
        }
      }
    }

    return null;
  }

  void _stopExecutionPolling(String transferId) {
    final poller = _executionPollers.remove(transferId);
    poller?.cancel();
    print('Stopped execution polling for: $transferId');
  }

  void _stopMonitoringTransfer(String transferId) {
    final timer = _timers.remove(transferId);
    timer?.cancel();
    _stopExecutionPolling(transferId);
    print('Stopped monitoring transfer: $transferId');
  }

  /// Manually trigger a check for all monitored transfers (useful for testing)
  Future<void> forceCheckAllMonitoredTransfers() async {
    if (_executionPollers.isNotEmpty) {
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
    _timers.clear();
    _executionPollers.clear();
  }
}

/// Provider for the reversible transfer monitoring service
final reversibleTransferMonitoringServiceProvider =
    Provider<ReversibleTransferMonitoringService>((ref) {
      final service = ReversibleTransferMonitoringService(ref);

      // Clean up when provider is disposed
      ref.onDispose(service.dispose);

      return service;
    });
