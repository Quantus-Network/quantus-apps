import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_titles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/utils/account_actions.dart';

/// The active account's actions in the header, each opening its sheet. The
/// Account menu offers the same actions from the same list.
class AccountToolbar extends ConsumerWidget {
  const AccountToolbar({super.key});

  /// The icon of each action, the same as on the mobile app's action cards,
  /// where proposing a multisig transfer shares Send's.
  static QuantusIcons _iconOf(AccountActionKind kind) => switch (kind) {
    AccountActionKind.receive => QuantusIcons.actionReceive,
    AccountActionKind.send || AccountActionKind.propose => QuantusIcons.actionSend,
    AccountActionKind.swap => QuantusIcons.actionSwap,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final actions = ref.watch(activeAccountActionsProvider);

    return ToolbarActionRow(
      edge: ToolbarActionEdge.trailing,
      children: [
        for (final action in actions)
          ToolbarAction(
            icon: _iconOf(action.kind),
            label: sheetTitle(l10n, sheetForAction(action.kind)),
            onPressed: action.isEnabled
                ? () => ref.read(shellSheetProvider.notifier).open(sheetForAction(action.kind))
                : null,
          ),
      ],
    );
  }
}
