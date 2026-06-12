import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pending_multisig_creation_record.dart';
import 'package:resonance_network_wallet/providers/multisig_creation_toast_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_creations_provider.dart';
import 'package:resonance_network_wallet/services/multisig_creation_reconciliation.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class MultisigCreationPollingService {
  final Ref _ref;
  final Map<String, Timer> _timers = {};
  final Set<String> _inFlight = {};
  static const _searchInterval = Duration(seconds: 5);
  static const _timeout = PendingMultisigCreationsNotifier.expireDuration;

  MultisigCreationPollingService(this._ref);

  Future<void> resumePendingCreations() async {
    final notifier = _ref.read(pendingMultisigCreationsProvider.notifier);
    await notifier.ready;

    for (final record in notifier.records) {
      final key = record.draft.accountId;
      if (_timers.containsKey(key)) continue;

      final elapsed = DateTime.now().difference(record.submittedAt);
      if (elapsed > _timeout) {
        quantusDebugPrint('[MultisigCreationPoller] expired pending creation, attempting recovery for $key');
        unawaited(_recoverExpired(record));
        continue;
      }

      quantusDebugPrint('[MultisigCreationPoller] resuming polling for $key');
      startPolling(record.draft, submittedAt: record.submittedAt);
    }
  }

  void startPolling(MultisigAccount draft, {DateTime? submittedAt}) {
    final key = draft.accountId;
    quantusDebugPrint('[MultisigCreationPoller] startPolling ${draft.accountId}');

    stopPolling(key);
    final startTime = submittedAt ?? DateTime.now();

    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > _timeout) {
        quantusDebugPrint('[MultisigCreationPoller] timeout for ${draft.accountId}');
        stopPolling(key);
        removePendingMultisigCreation(_ref, key);
        _ref.read(multisigCreationToastProvider.notifier).state = const MultisigCreationToastEvent(
          MultisigCreationToastKind.timeout,
        );
        return;
      }
      unawaited(_search(draft, key));
    });

    _timers[key] = timer;
    unawaited(_search(draft, key));
  }

  Future<void> _recoverExpired(PendingMultisigCreationRecord record) async {
    final key = record.draft.accountId;
    if (!_inFlight.add(key)) return;

    try {
      final service = _ref.read(multisigServiceProvider);
      final exists = await service.isMultisigIndexed(key);
      if (exists) {
        await _confirmCreation(record.draft, key, record.networkFee);
      } else {
        removePendingMultisigCreation(_ref, key);
        _ref.read(multisigCreationToastProvider.notifier).state = const MultisigCreationToastEvent(
          MultisigCreationToastKind.timeout,
        );
      }
    } catch (e, stackTrace) {
      quantusDebugPrint('[MultisigCreationPoller] recovery error for $key: $e');
      TelemetryService().sendError('multisig_creation_recovery_failed', error: e, stackTrace: stackTrace);
    } finally {
      _inFlight.remove(key);
    }
  }

  void stopPolling(String accountId) {
    _timers.remove(accountId)?.cancel();
  }

  Future<void> _search(MultisigAccount draft, String key) async {
    if (!_inFlight.add(key)) return;

    try {
      final service = _ref.read(multisigServiceProvider);
      final exists = await service.isMultisigIndexed(draft.accountId);
      if (!exists) {
        quantusDebugPrint('[MultisigCreationPoller] not on-chain yet: ${draft.accountId}');
        return;
      }

      quantusDebugPrint('[MultisigCreationPoller] confirmed ${draft.accountId}');

      final record = _ref.read(pendingMultisigCreationsProvider.notifier).recordFor(draft.accountId);
      if (record == null) {
        quantusDebugPrint(
          '[MultisigCreationPoller] missing pending creation for ${draft.accountId}; skipping history reconcile',
        );
        stopPolling(key);
        return;
      }

      await _confirmCreation(draft, key, record.networkFee);
    } catch (e) {
      quantusDebugPrint('[MultisigCreationPoller] search error for ${draft.accountId}: $e');
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> _confirmCreation(MultisigAccount draft, String key, BigInt networkFee) async {
    stopPolling(key);
    removePendingMultisigCreation(_ref, key);

    final existing = _ref.read(multisigAccountsProvider).value ?? [];
    if (!existing.any((a) => a.accountId == draft.accountId)) {
      await _ref.read(multisigAccountsProvider.notifier).add(draft);
      _ref.invalidate(discoveredMultisigsProvider);
    }

    await reconcileConfirmedMultisigCreation(_ref, draft, networkFee: networkFee);

    _ref.read(multisigCreationToastProvider.notifier).state = const MultisigCreationToastEvent(
      MultisigCreationToastKind.ready,
    );
  }

  /// Cancels all active polling timers (e.g. on logout).
  void stopAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  void dispose() => stopAll();
}

final multisigCreationPollingServiceProvider = Provider<MultisigCreationPollingService>((ref) {
  final service = MultisigCreationPollingService(ref);
  unawaited(service.resumePendingCreations());
  ref.onDispose(service.dispose);
  return service;
});
