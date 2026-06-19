import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_creation_toast_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

/// Shows toasts for background multisig creation confirmation events.
class MultisigCreationToastListener extends ConsumerWidget {
  const MultisigCreationToastListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<MultisigCreationToastEvent?>(multisigCreationToastProvider, (previous, next) {
      if (next == null) return;
      final l10n = ref.read(l10nProvider);
      final message = switch (next.kind) {
        MultisigCreationToastKind.ready => l10n.multisigCreateReadyToast,
        MultisigCreationToastKind.timeout => l10n.multisigCreateTimeoutToast,
      };
      if (next.kind == MultisigCreationToastKind.ready) {
        context.showSuccessToaster(message: message);
      } else {
        context.showErrorToaster(message: message);
      }
      ref.read(multisigCreationToastProvider.notifier).state = null;
    });

    return child;
  }
}
