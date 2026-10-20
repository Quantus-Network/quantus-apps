import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_switcher.dart';
import 'package:quantus_desktop_wallet/ui/shell/app_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/discreet_mode_toggle.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar_nav_item.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class Sidebar extends ConsumerWidget {
  static const double width = 240;

  final int currentIndex;
  final ValueChanged<int> onSelect;

  const Sidebar({super.key, required this.currentIndex, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final l10n = ref.watch(l10nProvider);
    final items = [
      (l10n.navDashboard, Icons.grid_view_rounded),
      (l10n.navAccount, Icons.account_balance_wallet_outlined),
      (l10n.navSend, Icons.north_east_rounded),
      (l10n.navReceive, Icons.south_west_rounded),
      (l10n.navSwap, Icons.swap_horiz_rounded),
    ];
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.bgSurface,
        border: Border(right: BorderSide(color: colors.borderHairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(12, 40, 12, 16), child: AccountSwitcher()),
          for (var i = 0; i < items.length; i++)
            SidebarNavItem(
              label: items[i].$1,
              icon: items[i].$2,
              shortcut: AppShell.shortcutLabel(i),
              selected: currentIndex == i,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          SidebarNavItem(
            label: l10n.navSettings,
            icon: Icons.settings_outlined,
            shortcut: AppShell.shortcutLabel(5),
            selected: currentIndex == 5,
            onTap: () => onSelect(5),
          ),
          const Padding(padding: EdgeInsets.fromLTRB(12, 8, 12, 16), child: DiscreetModeToggle()),
        ],
      ),
    );
  }
}
