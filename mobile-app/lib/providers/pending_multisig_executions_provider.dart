import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/pending_extrinsic_events_notifier.dart';

/// Executions submitted on-chain but not yet visible in the indexer.
class PendingMultisigExecutionsNotifier extends PendingExtrinsicEventsNotifier<PendingMultisigExecutionEvent> {
  @override
  String idOf(PendingMultisigExecutionEvent event) => event.id;

  @override
  PendingMultisigExecutionEvent withExtrinsicHash(PendingMultisigExecutionEvent event, String? extrinsicHash) {
    return event.copyWith(extrinsicHash: extrinsicHash);
  }
}

final pendingMultisigExecutionsProvider =
    NotifierProvider<PendingMultisigExecutionsNotifier, List<PendingMultisigExecutionEvent>>(
      PendingMultisigExecutionsNotifier.new,
    );

/// Pending executions excluded from the multisig activity feed below.
List<PendingMultisigExecutionEvent> pendingExecutionsExcludingMultisig(
  List<PendingMultisigExecutionEvent> all,
  String multisigAddress,
) {
  return all.where((e) => e.multisigAddress != multisigAddress).toList();
}

PendingMultisigExecutionEvent? findPendingExecutionForProposal(
  List<PendingMultisigExecutionEvent> all,
  String multisigAddress,
  int proposalId,
  String executorId,
) {
  for (final event in all) {
    if (event.multisigAddress == multisigAddress && event.proposalId == proposalId && event.executorId == executorId) {
      return event;
    }
  }
  return null;
}

void addPendingMultisigExecution(Ref ref, PendingMultisigExecutionEvent event) {
  addPendingExtrinsicEvent(ref, pendingMultisigExecutionsProvider, event);
}

void updatePendingMultisigExecution(Ref ref, String id, {String? extrinsicHash}) {
  updatePendingExtrinsicEvent(ref, pendingMultisigExecutionsProvider, id, extrinsicHash: extrinsicHash);
}

void removePendingMultisigExecution(Ref ref, String id) {
  removePendingExtrinsicEvent(ref, pendingMultisigExecutionsProvider, id);
}

PendingMultisigExecutionEvent? findPendingMultisigExecution(Ref ref, String id) {
  return findPendingExtrinsicEventById(ref.read(pendingMultisigExecutionsProvider), id, (event) => event.id);
}
