import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_proposals_provider.dart';
import 'package:resonance_network_wallet/services/multisig_proposal_reconciliation.dart';
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
    quantusDebugPrint('[MultisigProposalPoller] startPolling $key');

    stopPolling(key);
    final startTime = DateTime.now();

    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > _timeout) {
        quantusDebugPrint('[MultisigProposalPoller] timeout for $key');
        stopPolling(key);
        removePendingMultisigProposal(_ref, key);
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
    if (!_inFlight.add(key)) return;

    try {
      final service = _ref.read(multisigServiceProvider);
      final proposals = await service.getProposalsForMultisig(msig);
      final match = proposals.firstWhere(
        (p) =>
            p.proposer == pending.proposerId &&
            p.recipient == pending.recipient &&
            p.amount == pending.amount &&
            !p.createdAt.isBefore(pending.timestamp.subtract(const Duration(minutes: 2))),
        orElse: () => _noMatch,
      );

      if (identical(match, _noMatch)) {
        quantusDebugPrint('[MultisigProposalPoller] not indexed yet: $key');
        return;
      }

      quantusDebugPrint('[MultisigProposalPoller] confirmed $key (proposal #${match.id})');
      stopPolling(key);
      removePendingMultisigProposal(_ref, key);
      reconcileConfirmedProposal(_ref, msig);
    } catch (e) {
      quantusDebugPrint('[MultisigProposalPoller] search error for $key: $e');
    } finally {
      _inFlight.remove(key);
    }
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

final _noMatch = MultisigProposal(
  entityId: '',
  id: -1,
  multisigAddress: '',
  proposer: '',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  pallet: '',
  call: '',
  callRaw: '',
  recipient: '',
  amount: BigInt.zero,
  expiryBlock: 0,
  approvals: const [],
  deposit: BigInt.zero,
  fee: BigInt.zero,
  status: MultisigProposalStatus.active,
  threshold: 0,
  signerCount: 0,
);

final multisigProposalPollingServiceProvider = Provider<MultisigProposalPollingService>((ref) {
  final service = MultisigProposalPollingService(ref);
  ref.onDispose(service.dispose);
  return service;
});
