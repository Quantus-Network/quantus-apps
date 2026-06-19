import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_proposal_toast_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

/// Shows toasts for background multisig proposal confirmation events.
class MultisigProposalToastListener extends ConsumerWidget {
  const MultisigProposalToastListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<MultisigProposalToastEvent?>(multisigProposalToastProvider, (previous, next) {
      if (next == null) return;
      final l10n = ref.read(l10nProvider);
      final message = switch (next.kind) {
        MultisigProposalToastKind.timeout => l10n.multisigProposeTimeoutToast,
      };
      context.showErrorToaster(message: message);
      ref.read(multisigProposalToastProvider.notifier).clear();
    });

    return child;
  }
}
