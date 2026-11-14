import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_desktop_wallet/ui/components/window_header_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The top row of the sidebar. On macOS it is where the title bar was: the
/// traffic lights sit at its left, then the app's name.
class SidebarHeader extends StatelessWidget {
  const SidebarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return WindowHeaderRow(
      leadsTheWindow: true,
      children: [
        if (drawsOverTitleBar)
          Expanded(
            child: IgnorePointer(
              child: Text(
                appTitle,
                style: context.themeTextV3.bodyEmphasis.copyWith(color: context.colorsV3.textContent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else
          const Spacer(),
        const _SidebarButton(),
      ],
    );
  }
}

/// The top row of the pane: what the pane shows, and the active account's
/// actions when it shows the account. While the sidebar is hidden it also
/// holds the button that brings the sidebar back.
class PaneHeader extends ConsumerWidget {
  const PaneHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSidebarVisible = ref.watch(sidebarVisibleProvider);
    final active = ref.watch(activeAccountProvider).value;
    final showsAccount = ref.watch(sidebarSelectionProvider) == SidebarSelection.account;
    final title = showsAccount ? active?.account.name ?? '' : ref.watch(l10nProvider).settingsMiningRewards;

    return WindowHeaderRow(
      leadsTheWindow: !isSidebarVisible,
      children: [
        if (!isSidebarVisible) const _SidebarButton(),
        if (showsAccount && isEncryptedAccount(active?.account))
          const IgnorePointer(child: EncryptedLockBadge(size: 24)),
        Expanded(
          child: IgnorePointer(
            child: Text(
              title,
              style: context.themeTextV3.headingRow.copyWith(color: context.colorsV3.textContent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (showsAccount && active != null) const AccountToolbar(),
      ],
    );
  }
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
