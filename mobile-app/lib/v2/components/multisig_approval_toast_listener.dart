import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_approval_toast_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_cancellation_toast_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_execution_toast_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

/// Shows toasts for background multisig approval, execution, and cancellation events.
class MultisigApprovalToastListener extends ConsumerWidget {
  const MultisigApprovalToastListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<MultisigApprovalToastEvent?>(multisigApprovalToastProvider, (previous, next) {
      if (next == null) return;
      final l10n = ref.read(l10nProvider);
      final message = switch (next.kind) {
        MultisigApprovalToastKind.timeout => l10n.multisigApprovalTimeoutToast,
        MultisigApprovalToastKind.submitFailed => l10n.multisigApproveFailed,
      };
      context.showErrorToaster(message: message);
      ref.read(multisigApprovalToastProvider.notifier).clear();
    });

    ref.listen<MultisigExecutionToastEvent?>(multisigExecutionToastProvider, (previous, next) {
      if (next == null) return;
      final l10n = ref.read(l10nProvider);
      switch (next.kind) {
        case MultisigExecutionToastKind.timeout:
          context.showErrorToaster(message: l10n.multisigExecutionTimeoutToast);
        case MultisigExecutionToastKind.submitFailed:
          context.showErrorToaster(message: l10n.multisigExecuteFailed);
        case MultisigExecutionToastKind.executedByOther:
          context.showInfoToaster(message: l10n.multisigExecutedByOtherToast);
      }
      ref.read(multisigExecutionToastProvider.notifier).clear();
    });

    ref.listen<MultisigCancellationToastEvent?>(multisigCancellationToastProvider, (previous, next) {
      if (next == null) return;
      final l10n = ref.read(l10nProvider);
      final message = switch (next.kind) {
        MultisigCancellationToastKind.timeout => l10n.multisigCancelTimeoutToast,
        MultisigCancellationToastKind.submitFailed => l10n.multisigCancelFailed,
      };
      context.showErrorToaster(message: message);
      ref.read(multisigCancellationToastProvider.notifier).clear();
    });

    return child;
  }
}
