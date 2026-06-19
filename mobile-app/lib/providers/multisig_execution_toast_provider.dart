import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MultisigExecutionToastKind { timeout, executedByOther }

class MultisigExecutionToastEvent {
  const MultisigExecutionToastEvent(this.kind);

  final MultisigExecutionToastKind kind;
}

class MultisigExecutionToastNotifier extends Notifier<MultisigExecutionToastEvent?> {
  @override
  MultisigExecutionToastEvent? build() => null;

  void show(MultisigExecutionToastKind kind) {
    state = MultisigExecutionToastEvent(kind);
  }

  void clear() {
    state = null;
  }
}

final multisigExecutionToastProvider = NotifierProvider<MultisigExecutionToastNotifier, MultisigExecutionToastEvent?>(
  MultisigExecutionToastNotifier.new,
);
