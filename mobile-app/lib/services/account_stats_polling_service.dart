import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/account_stats_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';

/// Service that handles account stats polling - refreshes transaction history
/// every minute to keep the UI up to date with the latest blockchain state.
class AccountStatsPollingService {
  final Ref _ref;
  Timer? _pollingTimer;
  bool _isPolling = false;

  AccountStatsPollingService(this._ref);

  /// Starts the account stats polling.
  /// This should be called when the app starts and accounts are available.
  void startPolling() {
    if (_isPolling) return;

    _isPolling = true;
    _scheduleNextPoll();
    print('Account stats polling started');
  }

  /// Stops the account stats polling.
  /// This should be called when the app is disposed or user logs out.
  void stopPolling() {
    if (!_isPolling && _pollingTimer == null) {
      return;
    }
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    print('Account stats polling stopped');
  }

  /// Pauses polling temporarily (e.g., when app goes to background)
  void pausePolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    print('Account stats polling paused');
  }

  /// Resumes polling if it was previously started
  void resumePolling() {
    if (_isPolling && _pollingTimer == null) {
      _scheduleNextPoll();
      print('Account stats polling resumed');
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
      print('Performing account stats poll...');

      await _ref.read(accountsStatsProvider.notifier).fetchStats();

      print('Account stats poll completed');
    } catch (e) {
      print('Error during account stats poll: $e');
    } finally {
      // Schedule the next poll regardless of success/failure
      if (_isPolling) {
        _scheduleNextPoll();
      }
    }
  }

  /// Manually trigger a history refresh (useful for pull-to-refresh)
  Future<void> triggerManualRefresh() async {
    print('Account stats poller: Manual Refresh!');

    await _ref.read(accountsStatsProvider.notifier).fetchStats();
  }

  void dispose() {
    stopPolling();
  }
}

/// Provider for the account stats polling service
final accountStatsPollingServiceProvider = Provider<AccountStatsPollingService>(
  (ref) {
    final service = AccountStatsPollingService(ref);

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
  },
);
