import 'package:flutter_riverpod/legacy.dart';

enum MultisigCreationToastKind { ready, timeout, submitFailed }

class MultisigCreationToastEvent {
  const MultisigCreationToastEvent(this.kind);

  final MultisigCreationToastKind kind;
}

final multisigCreationToastProvider = StateProvider<MultisigCreationToastEvent?>((ref) => null);
