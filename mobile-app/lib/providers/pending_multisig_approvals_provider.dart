import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/pending_extrinsic_events_notifier.dart';

/// Approvals submitted on-chain but not yet visible in the indexer.
class PendingMultisigApprovalsNotifier extends PendingExtrinsicEventsNotifier<PendingMultisigApprovalEvent> {
  @override
  String idOf(PendingMultisigApprovalEvent event) => event.id;

  @override
  PendingMultisigApprovalEvent withExtrinsicHash(PendingMultisigApprovalEvent event, String? extrinsicHash) {
    return event.copyWith(extrinsicHash: extrinsicHash);
  }
}

final pendingMultisigApprovalsProvider =
    NotifierProvider<PendingMultisigApprovalsNotifier, List<PendingMultisigApprovalEvent>>(
      PendingMultisigApprovalsNotifier.new,
    );

PendingMultisigApprovalEvent? findPendingApprovalForProposal(
  List<PendingMultisigApprovalEvent> all,
  String multisigAddress,
  int proposalId,
  String approverId,
) {
  for (final event in all) {
    if (event.multisigAddress == multisigAddress && event.proposalId == proposalId && event.approverId == approverId) {
      return event;
    }
  }
  return null;
}

void addPendingMultisigApproval(Ref ref, PendingMultisigApprovalEvent event) {
  addPendingExtrinsicEvent(ref, pendingMultisigApprovalsProvider, event);
}

void updatePendingMultisigApproval(Ref ref, String id, {String? extrinsicHash}) {
  updatePendingExtrinsicEvent(ref, pendingMultisigApprovalsProvider, id, extrinsicHash: extrinsicHash);
}

void removePendingMultisigApproval(Ref ref, String id) {
  removePendingExtrinsicEvent(ref, pendingMultisigApprovalsProvider, id);
}

PendingMultisigApprovalEvent? findPendingMultisigApproval(Ref ref, String id) {
  return findPendingExtrinsicEventById(ref.read(pendingMultisigApprovalsProvider), id, (event) => event.id);
}
