import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_proposal_toast_provider.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/multisig_proposal_reconciliation.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Polls the indexer until a freshly submitted proposal becomes visible, then
/// clears the pending overlay and refreshes proposal state.
class MultisigProposalPollingService {
  final Ref _ref;
  final Map<String, Timer> _timers = {};
  final Set<String> _inFlight = {};
  static const _searchInterval = Duration(seconds: 5);
  static const _timeout = Duration(minutes: 5);

  MultisigProposalPollingService(this._ref);

  void startPolling(MultisigAccount msig, PendingMultisigProposalEvent pending) {
    final key = pending.id;
    if (pending.extrinsicHash == null) {
      quantusDebugPrint(
        '[MultisigProposalPoller] ERROR: cannot poll $key — no extrinsicHash. '
        'Waiting for submission to complete.',
      );
      return;
    }

    quantusDebugPrint('[MultisigProposalPoller] startPolling $key hash=${pending.extrinsicHash}');

    stopPolling(key);
    final startTime = DateTime.now();

    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > _timeout) {
        quantusDebugPrint('[MultisigProposalPoller] timeout for $key');
        stopPolling(key);
        unawaited(_handleTimeout(msig, pending));
        return;
      }
      unawaited(_search(msig, pending));
    });

    _timers[key] = timer;
    unawaited(_search(msig, pending));
  }

  void stopPolling(String id) {
    _timers.remove(id)?.cancel();
  }

  Future<void> _search(MultisigAccount msig, PendingMultisigProposalEvent pending) async {
    final key = pending.id;
    if (pending.extrinsicHash == null) return;
    if (!_inFlight.add(key)) return;

    try {
      final confirmed = await _confirmIfIndexed(msig, pending);
      if (!confirmed) {
        quantusDebugPrint('[MultisigProposalPoller] not indexed yet: $key');
      }
    } catch (e) {
      quantusDebugPrint('[MultisigProposalPoller] search error for $key: $e');
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> _handleTimeout(MultisigAccount msig, PendingMultisigProposalEvent pending) async {
    final key = pending.id;
    try {
      quantusDebugPrint('[MultisigProposalPoller] final indexer check before timeout for $key');
      final confirmed = await _confirmIfIndexed(msig, pending);
      if (confirmed) return;
    } catch (e) {
      quantusDebugPrint('[MultisigProposalPoller] final check error for $key: $e');
    }

    if (findPendingMultisigProposal(_ref, key) == null) return;

    quantusDebugPrint('[MultisigProposalPoller] giving up on $key');
    removePendingMultisigProposal(_ref, key);
    _ref.read(multisigProposalToastProvider.notifier).show(MultisigProposalToastKind.timeout);
  }

  Future<bool> _confirmIfIndexed(MultisigAccount msig, PendingMultisigProposalEvent pending) async {
    final key = pending.id;
    final hash = pending.extrinsicHash;
    if (hash == null) return false;

    final historyService = _ref.read(chainHistoryServiceProvider);
    final indexed = await historyService.searchProposalCreatedByExtrinsicHash(extrinsicHash: hash);
    if (indexed == null) return false;

    quantusDebugPrint('[MultisigProposalPoller] confirmed $key at block ${indexed.blockNumber}');
    stopPolling(key);
    removePendingMultisigProposal(_ref, key);
    await reconcileIndexedProposalCreation(_ref, msig, indexed);
    invalidateAccountBalances(_ref, {pending.proposerId});
    return true;
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

final multisigProposalPollingServiceProvider = Provider<MultisigProposalPollingService>((ref) {
  final service = MultisigProposalPollingService(ref);
  ref.onDispose(service.dispose);
  return service;
});
