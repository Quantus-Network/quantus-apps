import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Approvals submitted on-chain but not yet visible in the indexer.
class PendingMultisigApprovalsNotifier extends Notifier<List<PendingMultisigApprovalEvent>> {
  @override
  List<PendingMultisigApprovalEvent> build() => [];

  void add(PendingMultisigApprovalEvent event) {
    state = [...state, event];
  }

  void update(String id, {String? extrinsicHash}) {
    state = [
      for (final event in state)
        if (event.id == id) event.copyWith(extrinsicHash: extrinsicHash) else event,
    ];
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  void clear() {
    state = [];
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
) {
  for (final event in all) {
    if (event.multisigAddress == multisigAddress && event.proposalId == proposalId) {
      return event;
    }
  }
  return null;
}

void addPendingMultisigApproval(Ref ref, PendingMultisigApprovalEvent event) {
  ref.read(pendingMultisigApprovalsProvider.notifier).add(event);
}

void updatePendingMultisigApproval(Ref ref, String id, {String? extrinsicHash}) {
  ref.read(pendingMultisigApprovalsProvider.notifier).update(id, extrinsicHash: extrinsicHash);
}

void removePendingMultisigApproval(Ref ref, String id) {
  ref.read(pendingMultisigApprovalsProvider.notifier).remove(id);
}

PendingMultisigApprovalEvent? findPendingMultisigApproval(Ref ref, String id) {
  for (final event in ref.read(pendingMultisigApprovalsProvider)) {
    if (event.id == id) return event;
  }
  return null;
}
