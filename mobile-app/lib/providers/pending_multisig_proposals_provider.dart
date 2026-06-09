import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/pending_extrinsic_events_notifier.dart';

/// Transfer proposals submitted on-chain but not yet visible in the indexer.
class PendingMultisigProposalsNotifier extends PendingExtrinsicEventsNotifier<PendingMultisigProposalEvent> {
  @override
  String idOf(PendingMultisigProposalEvent event) => event.id;

  @override
  PendingMultisigProposalEvent withExtrinsicHash(PendingMultisigProposalEvent event, String? extrinsicHash) {
    return event.copyWith(extrinsicHash: extrinsicHash);
  }
}

final pendingMultisigProposalsProvider =
    NotifierProvider<PendingMultisigProposalsNotifier, List<PendingMultisigProposalEvent>>(
      PendingMultisigProposalsNotifier.new,
    );

/// Pending proposals shown in the multisig open section (pinned at top).
List<PendingMultisigProposalEvent> pendingProposalsForMultisig(
  List<PendingMultisigProposalEvent> all,
  String multisigAddress,
) {
  return all.where((p) => p.multisigAddress == multisigAddress).toList();
}

/// Pending proposals excluded from the multisig activity feed below.
List<PendingMultisigProposalEvent> pendingProposalsExcludingMultisig(
  List<PendingMultisigProposalEvent> all,
  String multisigAddress,
) {
  return all.where((p) => p.multisigAddress != multisigAddress).toList();
}

void addPendingMultisigProposal(Ref ref, PendingMultisigProposalEvent event) {
  addPendingExtrinsicEvent(ref, pendingMultisigProposalsProvider, event);
}

void updatePendingMultisigProposal(Ref ref, String id, {String? extrinsicHash}) {
  updatePendingExtrinsicEvent(ref, pendingMultisigProposalsProvider, id, extrinsicHash: extrinsicHash);
}

void removePendingMultisigProposal(Ref ref, String id) {
  removePendingExtrinsicEvent(ref, pendingMultisigProposalsProvider, id);
}

void clearPendingMultisigProposals(Ref ref) {
  ref.read(pendingMultisigProposalsProvider.notifier).clear();
}

PendingMultisigProposalEvent? findPendingMultisigProposal(Ref ref, String id) {
  return findPendingExtrinsicEventById(ref.read(pendingMultisigProposalsProvider), id, (event) => event.id);
}
