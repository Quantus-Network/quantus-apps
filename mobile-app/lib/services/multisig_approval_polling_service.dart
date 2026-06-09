import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_approval_toast_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_approvals_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/multisig_approval_reconciliation.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Polls the indexer until a freshly submitted approval is reflected on the
/// proposal, then clears the pending overlay and refreshes proposal state.
class MultisigApprovalPollingService {
  final Ref _ref;
  final Map<String, Timer> _timers = {};
  final Set<String> _inFlight = {};
  static const _searchInterval = Duration(seconds: 5);
  static const _timeout = Duration(minutes: 5);

  MultisigApprovalPollingService(this._ref);

  void startPolling(MultisigAccount msig, PendingMultisigApprovalEvent pending) {
    final key = pending.id;
    if (pending.extrinsicHash == null) {
      quantusDebugPrint(
        '[MultisigApprovalPoller] ERROR: cannot poll $key — no extrinsicHash. '
        'Waiting for submission to complete.',
      );
      return;
    }

    quantusDebugPrint('[MultisigApprovalPoller] startPolling $key hash=${pending.extrinsicHash}');

    stopPolling(key);
    final startTime = DateTime.now();

    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > _timeout) {
        quantusDebugPrint('[MultisigApprovalPoller] timeout for $key');
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

  Future<void> _search(MultisigAccount msig, PendingMultisigApprovalEvent pending) async {
    final key = pending.id;
    if (pending.extrinsicHash == null) return;
    if (!_inFlight.add(key)) return;

    try {
      final confirmed = await _confirmIfIndexed(msig, pending);
      if (!confirmed) {
        quantusDebugPrint('[MultisigApprovalPoller] not indexed yet: $key');
      }
    } catch (e) {
      quantusDebugPrint('[MultisigApprovalPoller] search error for $key: $e');
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<void> _handleTimeout(MultisigAccount msig, PendingMultisigApprovalEvent pending) async {
    final key = pending.id;
    try {
      quantusDebugPrint('[MultisigApprovalPoller] final indexer check before timeout for $key');
      final confirmed = await _confirmIfIndexed(msig, pending);
      if (confirmed) return;
    } catch (e) {
      quantusDebugPrint('[MultisigApprovalPoller] final check error for $key: $e');
    }

    if (findPendingMultisigApproval(_ref, key) == null) return;

    quantusDebugPrint('[MultisigApprovalPoller] giving up on $key');
    removePendingMultisigApproval(_ref, key);
    _ref.read(multisigApprovalToastProvider.notifier).show(MultisigApprovalToastKind.timeout);
  }

  Future<bool> _confirmIfIndexed(MultisigAccount msig, PendingMultisigApprovalEvent pending) async {
    final key = pending.id;
    final hash = pending.extrinsicHash;
    if (hash == null) return false;

    final multisigService = _ref.read(multisigServiceProvider);
    final proposal = await multisigService.getProposal(msig, pending.proposalId);
    if (proposal == null || !proposal.didApprove(pending.approverId)) return false;

    final historyService = _ref.read(chainHistoryServiceProvider);
    final indexed = await historyService.searchSignerApprovedByExtrinsicHash(extrinsicHash: hash);
    if (indexed == null) return false;

    quantusDebugPrint('[MultisigApprovalPoller] confirmed $key proposal ${pending.proposalId}');
    stopPolling(key);
    removePendingMultisigApproval(_ref, key);
    await reconcileIndexedApproval(_ref, msig, indexed);
    return true;
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

final multisigApprovalPollingServiceProvider = Provider<MultisigApprovalPollingService>((ref) {
  final service = MultisigApprovalPollingService(ref);
  ref.onDispose(service.dispose);
  return service;
});
