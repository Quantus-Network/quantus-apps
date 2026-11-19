import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_balance.dart';
import 'package:wallet_core/providers/account_providers.dart';

/// The time now. Tests set the clock through it.
final currentTimeProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// How current the open wallet is, as the window can tell: by the active
/// account's balance, which every poll and refresh reads again. A poll
/// catches what its other reads fail with, so only the balance says
/// whether the network answered.
@immutable
class SyncStatus {
  const SyncStatus({this.isSyncing = false, this.lastSyncedAt, this.hasFailed = false});

  /// Whether the balance is being read now.
  final bool isSyncing;

  /// When the balance was last read, or null before it ever was.
  final DateTime? lastSyncedAt;

  /// Whether the latest read failed; [lastSyncedAt] is still the last good
  /// one.
  final bool hasFailed;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.isSyncing == isSyncing &&
      other.lastSyncedAt == lastSyncedAt &&
      other.hasFailed == hasFailed;

  @override
  int get hashCode => Object.hash(isSyncing, lastSyncedAt, hasFailed);

  @override
  String toString() => 'SyncStatus(isSyncing: $isSyncing, lastSyncedAt: $lastSyncedAt, hasFailed: $hasFailed)';
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    ref.listen(_activeBalanceProvider, (previous, next) {
      if (next != null) state = _after(state, previous, next);
    });
    final balance = ref.read(_activeBalanceProvider);
    return balance == null ? const SyncStatus() : _after(const SyncStatus(), null, balance);
  }

  /// Where [current] stands once the balance is [balance], having been
  /// [previous].
  SyncStatus _after(SyncStatus current, AsyncValue<BigInt>? previous, AsyncValue<BigInt> balance) {
    if (balance.isLoading) {
      return SyncStatus(isSyncing: true, lastSyncedAt: current.lastSyncedAt, hasFailed: current.hasFailed);
    }
    if (balance.hasError) return SyncStatus(lastSyncedAt: current.lastSyncedAt, hasFailed: true);
    // A balance read before, shown again on a switch to its account, is no
    // new read.
    final isNewRead = previous == null || previous.isLoading;
    return SyncStatus(lastSyncedAt: isNewRead ? ref.read(currentTimeProvider)() : current.lastSyncedAt);
  }
}

/// The active account's balance as the window shows it, or null with no
/// active account.
final _activeBalanceProvider = Provider<AsyncValue<BigInt>?>((ref) {
  final account = ref.watch(activeAccountProvider).value?.account;
  return account == null ? null : accountBalanceWith(ref.watch, account);
});
