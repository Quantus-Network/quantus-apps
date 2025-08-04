import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
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
  static const Duration _timeBuffer = Duration(
    seconds: 30,
  ); // Start monitoring the timer x seconds before

  ReversibleTransferMonitoringService(this._ref) {
    _listenToTransactions();
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

    // Start monitoring transfers approaching execution
    for (final transfer in scheduledTransfers) {
      final remainingTime = transfer.remainingTime;

      // If we're not already monitoring this transfer and it's close
      // to execution
      if (!_timers.containsKey(transfer.id) && remainingTime <= _timeBuffer) {
        _startMonitoringTransfer(transfer);
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

  void _startMonitoringTransfer(ReversibleTransferEvent transfer) {
    print('Starting to monitor reversible transfer timer: ${transfer.id}');

    // Create a timer that checks remaining time every second
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkTransferTimer(transfer);
    });

    _timers[transfer.id] = timer;

    // Check immediately in case it's already at zero
    _checkTransferTimer(transfer);
  }

  void _checkTransferTimer(ReversibleTransferEvent transfer) {
    final remainingTime = transfer.remainingTime;

    // If timer hit zero and we're not already polling for execution
    if (remainingTime <= Duration.zero &&
        !_executionPollers.containsKey(transfer.id)) {
      print(
        'Reversible transfer timer hit zero: ${transfer.id} - '
        'starting execution polling',
      );
      _startExecutionPolling(transfer);

      // Stop the timer monitoring since we're now polling for execution
      _stopTimerMonitoring(transfer.id);
    }
  }

  void _startExecutionPolling(ReversibleTransferEvent transfer) {
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
        // to executed list
        _ref
            .read(paginationControllerProvider.notifier)
            .updateReversibleTransferToExecuted(
              transfer.extrinsicHash!,
              status,
            );

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

  void _stopTimerMonitoring(String transferId) {
    final timer = _timers.remove(transferId);
    timer?.cancel();
  }

  void _stopExecutionPolling(String transferId) {
    final poller = _executionPollers.remove(transferId);
    poller?.cancel();
    print('Stopped execution polling for: $transferId');
  }

  void _stopMonitoringTransfer(String transferId) {
    _stopTimerMonitoring(transferId);
    _stopExecutionPolling(transferId);
    print('Stopped monitoring transfer: $transferId');
  }

  /// Manually trigger a check for all monitored transfers (useful for testing)
  Future<void> forceCheckAllMonitoredTransfers() async {
    if (_executionPollers.isNotEmpty) {
      // We have monitored transfers, trigger a general refresh
      _ref.invalidate(paginationControllerProvider);
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
      ref.onDispose(() => service.dispose());

      return service;
    });
