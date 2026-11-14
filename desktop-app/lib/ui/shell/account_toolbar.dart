import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_titles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The active account's actions as buttons, each opening its sheet. The
/// Account menu offers the same actions from the same list.
class AccountToolbar extends ConsumerWidget {
  const AccountToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final actions = ref.watch(activeAccountActionsProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        for (final action in actions)
          QuantusButton.simple(
            label: sheetTitle(l10n, sheetForAction(action.kind)),
            width: null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            variant: ButtonVariant.staged,
            isDisabled: !action.isEnabled,
            onTap: () => ref.read(shellSheetProvider.notifier).open(sheetForAction(action.kind)),
          ),
      ],
    );
  }
}
