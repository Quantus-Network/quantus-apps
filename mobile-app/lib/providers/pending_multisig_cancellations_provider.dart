import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/pending_extrinsic_events_notifier.dart';

/// Cancellations submitted on-chain but not yet visible in the indexer.
class PendingMultisigCancellationsNotifier extends PendingExtrinsicEventsNotifier<PendingMultisigCancellationEvent> {
  @override
  String idOf(PendingMultisigCancellationEvent event) => event.id;

  @override
  PendingMultisigCancellationEvent withExtrinsicHash(PendingMultisigCancellationEvent event, String? extrinsicHash) {
    return event.copyWith(extrinsicHash: extrinsicHash);
  }
}

final pendingMultisigCancellationsProvider =
    NotifierProvider<PendingMultisigCancellationsNotifier, List<PendingMultisigCancellationEvent>>(
      PendingMultisigCancellationsNotifier.new,
    );

/// Pending cancellations excluded from the multisig activity feed below.
List<PendingMultisigCancellationEvent> pendingCancellationsExcludingMultisig(
  List<PendingMultisigCancellationEvent> all,
  String multisigAddress,
) {
  return all.where((e) => e.multisigAddress != multisigAddress).toList();
}

PendingMultisigCancellationEvent? findPendingCancellationForProposal(
  List<PendingMultisigCancellationEvent> all,
  String multisigAddress,
  int proposalId,
  String proposerId,
) {
  for (final event in all) {
    if (event.multisigAddress == multisigAddress && event.proposalId == proposalId && event.proposerId == proposerId) {
      return event;
    }
  }
  return null;
}

void addPendingMultisigCancellation(Ref ref, PendingMultisigCancellationEvent event) {
  addPendingExtrinsicEvent(ref, pendingMultisigCancellationsProvider, event);
}

void updatePendingMultisigCancellation(Ref ref, String id, {String? extrinsicHash}) {
  updatePendingExtrinsicEvent(ref, pendingMultisigCancellationsProvider, id, extrinsicHash: extrinsicHash);
}

void removePendingMultisigCancellation(Ref ref, String id) {
  removePendingExtrinsicEvent(ref, pendingMultisigCancellationsProvider, id);
}

PendingMultisigCancellationEvent? findPendingMultisigCancellation(Ref ref, String id) {
  return findPendingExtrinsicEventById(ref.read(pendingMultisigCancellationsProvider), id, (event) => event.id);
}
