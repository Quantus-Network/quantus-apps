import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Transfer proposals submitted on-chain but not yet visible in the indexer.
class PendingMultisigProposalsNotifier extends Notifier<List<PendingMultisigProposalEvent>> {
  @override
  List<PendingMultisigProposalEvent> build() => [];

  void add(PendingMultisigProposalEvent event) {
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
  ref.read(pendingMultisigProposalsProvider.notifier).add(event);
}

void updatePendingMultisigProposal(Ref ref, String id, {String? extrinsicHash}) {
  ref.read(pendingMultisigProposalsProvider.notifier).update(id, extrinsicHash: extrinsicHash);
}

void removePendingMultisigProposal(Ref ref, String id) {
  ref.read(pendingMultisigProposalsProvider.notifier).remove(id);
}

void clearPendingMultisigProposals(Ref ref) {
  ref.read(pendingMultisigProposalsProvider.notifier).clear();
}

PendingMultisigProposalEvent? findPendingMultisigProposal(Ref ref, String id) {
  for (final event in ref.read(pendingMultisigProposalsProvider)) {
    if (event.id == id) return event;
  }
  return null;
}
