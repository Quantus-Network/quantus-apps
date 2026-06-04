import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Transfer proposals submitted on-chain but not yet visible in the indexer.
class PendingMultisigProposalsNotifier extends StateNotifier<List<PendingMultisigProposalEvent>> {
  PendingMultisigProposalsNotifier() : super([]);

  void add(PendingMultisigProposalEvent event) {
    state = [...state, event];
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  void clear() {
    state = [];
  }
}

final pendingMultisigProposalsProvider =
    StateNotifierProvider<PendingMultisigProposalsNotifier, List<PendingMultisigProposalEvent>>((ref) {
      return PendingMultisigProposalsNotifier();
    });

void addPendingMultisigProposal(Ref ref, PendingMultisigProposalEvent event) {
  ref.read(pendingMultisigProposalsProvider.notifier).add(event);
}

void removePendingMultisigProposal(Ref ref, String id) {
  ref.read(pendingMultisigProposalsProvider.notifier).remove(id);
}

void clearPendingMultisigProposals(Ref ref) {
  ref.read(pendingMultisigProposalsProvider.notifier).clear();
}
