import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MultisigProposalToastKind { timeout }

class MultisigProposalToastEvent {
  const MultisigProposalToastEvent(this.kind);

  final MultisigProposalToastKind kind;
}

class MultisigProposalToastNotifier extends Notifier<MultisigProposalToastEvent?> {
  @override
  MultisigProposalToastEvent? build() => null;

  void show(MultisigProposalToastKind kind) {
    state = MultisigProposalToastEvent(kind);
  }

  void clear() {
    state = null;
  }
}

final multisigProposalToastProvider = NotifierProvider<MultisigProposalToastNotifier, MultisigProposalToastEvent?>(
  MultisigProposalToastNotifier.new,
);
