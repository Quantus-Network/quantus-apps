import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MultisigCancellationToastKind { timeout, submitFailed }

class MultisigCancellationToastEvent {
  const MultisigCancellationToastEvent(this.kind);

  final MultisigCancellationToastKind kind;
}

class MultisigCancellationToastNotifier extends Notifier<MultisigCancellationToastEvent?> {
  @override
  MultisigCancellationToastEvent? build() => null;

  void show(MultisigCancellationToastKind kind) {
    state = MultisigCancellationToastEvent(kind);
  }

  void clear() {
    state = null;
  }
}

final multisigCancellationToastProvider =
    NotifierProvider<MultisigCancellationToastNotifier, MultisigCancellationToastEvent?>(
      MultisigCancellationToastNotifier.new,
    );
