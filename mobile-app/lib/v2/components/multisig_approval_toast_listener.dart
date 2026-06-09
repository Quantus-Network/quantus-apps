import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_approval_toast_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

/// Shows toasts for background multisig approval confirmation events.
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

    return child;
  }
}
