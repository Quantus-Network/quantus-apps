import 'package:flutter_riverpod/legacy.dart';

enum MultisigProposalToastKind { timeout, submitFailed }

class MultisigProposalToastEvent {
  const MultisigProposalToastEvent(this.kind);

  final MultisigProposalToastKind kind;
}

final multisigProposalToastProvider = StateProvider<MultisigProposalToastEvent?>((ref) => null);
