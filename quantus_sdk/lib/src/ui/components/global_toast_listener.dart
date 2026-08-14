import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/global_toast_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

/// Renders app-wide toasts requested through [globalToastProvider].
///
/// Mount this once near the app root so any background event (multisig
/// polling, submission failures, etc.) can surface a toast without a
/// [BuildContext].
class GlobalToastListener extends ConsumerWidget {
  const GlobalToastListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ToastMessage?>(globalToastProvider, (previous, next) {
      if (next == null) return;
      switch (next.type) {
        case ToastType.success:
          context.showSuccessToaster(message: next.message);
        case ToastType.error:
          context.showErrorToaster(message: next.message);
        case ToastType.info:
          context.showInfoToaster(message: next.message);
        case ToastType.warning:
          context.showWarningToaster(message: next.message);
        case ToastType.copy:
          context.showCopyToaster(message: next.message);
      }
      ref.read(globalToastProvider.notifier).clear();
    });

    return child;
  }
}
