import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MultisigApprovalToastKind { timeout }

class MultisigApprovalToastEvent {
  const MultisigApprovalToastEvent(this.kind);

  final MultisigApprovalToastKind kind;
}

class MultisigApprovalToastNotifier extends Notifier<MultisigApprovalToastEvent?> {
  @override
  MultisigApprovalToastEvent? build() => null;

  void show(MultisigApprovalToastKind kind) {
    state = MultisigApprovalToastEvent(kind);
  }

  void clear() {
    state = null;
  }
}

final multisigApprovalToastProvider = NotifierProvider<MultisigApprovalToastNotifier, MultisigApprovalToastEvent?>(
  MultisigApprovalToastNotifier.new,
);
