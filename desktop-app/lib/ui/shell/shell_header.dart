import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_note_text.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/window_header_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The bar across the top of the window. On macOS it is where the title bar
/// was: the traffic lights sit at its left. Then the wordmark, the sidebar's
/// switch and, at the right, the active account's actions.
///
/// With the sidebar shown the bar names no account: the sidebar's selected
/// row does. With it hidden nothing else would, so the bar names the account,
/// or Mining Rewards when that is shown.
class ShellTopBar extends ConsumerWidget {
  const ShellTopBar({super.key});

  /// The space between the bar's ends and what it holds.
  static const double edgePadding = 20;

  /// The QUANTUS wordmark.
  static const wordmarkKey = Key('shell-top-bar-wordmark');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSidebarVisible = ref.watch(sidebarVisibleProvider);
    final active = ref.watch(activeAccountProvider).value;
    final showsAccount = ref.watch(sidebarSelectionProvider) == SidebarSelection.account;
    final titleStyle = context.themeTextV3.headingRow.copyWith(color: context.colorsV3.textContent);
    // With the sidebar hidden, a note about the account shows beside its name.
    final note = ref.watch(accountNoteProvider);

    return WindowHeaderRow(
      leadsTheWindow: true,
      edgePadding: edgePadding,
      children: [
        IgnorePointer(
          child: Image.asset(
            'assets/quantus_orange_logo.png',
            key: wordmarkKey,
            height: _wordmarkHeight,
            semanticLabel: appTitle,
          ),
        ),
        const _SidebarButton(),
        Expanded(
          child: isSidebarVisible
              ? const SizedBox.shrink()
              : IgnorePointer(
                  child: showsAccount
                      ? active == null
                            ? const SizedBox.shrink()
                            : Row(
                                children: [
                                  Flexible(
                                    child: AccountLabel(account: active.account, style: titleStyle),
                                  ),
                                  if (note != null && note.accountId == active.account.accountId) ...[
                                    const SizedBox(width: 14),
                                    Flexible(child: AccountNoteText(note: note)),
                                  ],
                                ],
                              )
                      : Text(
                          ref.watch(l10nProvider).settingsMiningRewards,
                          style: titleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
        ),
        if (showsAccount && active != null) const AccountToolbar(),
      ],
    );
  }

  /// The wordmark's height, its letters about a capital's height of the text
  /// beside it.
  static const double _wordmarkHeight = 12;
}

/// Hides the sidebar, or shows it again.
class _SidebarButton extends ConsumerWidget {
  const _SidebarButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final isSidebarVisible = ref.watch(sidebarVisibleProvider);

    return IconButton(
      icon: const Icon(CupertinoIcons.sidebar_left, size: 18),
      color: context.colorsV3.textMuted,
      visualDensity: VisualDensity.compact,
      tooltip: isSidebarVisible ? l10n.desktopMenuHideSidebar : l10n.desktopMenuShowSidebar,
      onPressed: () => ref.read(sidebarVisibleProvider.notifier).toggle(),
    );
  }
}
