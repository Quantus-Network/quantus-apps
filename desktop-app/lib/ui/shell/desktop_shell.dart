import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/app_menu.dart';
import 'package:quantus_desktop_wallet/ui/shell/app_menu_bar.dart';
import 'package:quantus_desktop_wallet/ui/shell/mining_rewards_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The window's frame: the menus, the sidebar, the pane for what the sidebar
/// has selected under its header, and the sheet over them when one is open.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  void _present(ShellSheet? sheet) {
    if (sheet == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => ShellSheetView(sheet: sheet),
    ).whenComplete(() {
      if (mounted) ref.read(shellSheetProvider.notifier).closed();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ShellSheet?>(shellSheetProvider, (_, sheet) => _present(sheet));

    final useNativeMenuBar = defaultTargetPlatform == TargetPlatform.macOS;
    final isSidebarVisible = ref.watch(sidebarVisibleProvider);

    return Scaffold(
      body: AppMenuBar(
        useNativeMenuBar: useNativeMenuBar,
        menus: buildAppMenus(
          l10n: ref.watch(l10nProvider),
          useNativeMenuBar: useNativeMenuBar,
          accountActions: ref.watch(activeAccountActionsProvider),
          isSidebarVisible: isSidebarVisible,
          canOpenSheet: ref.watch(shellSheetProvider) == null,
          onOpenSheet: (sheet) => ref.read(shellSheetProvider.notifier).open(sheet),
          onToggleSidebar: () => ref.read(sidebarVisibleProvider.notifier).toggle(),
          onCloseWindow: () => ref.read(requestAppExitProvider)(),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isSidebarVisible) const Sidebar(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PaneHeader(),
                  Expanded(
                    child: switch (ref.watch(sidebarSelectionProvider)) {
                      SidebarSelection.account => const AccountPane(),
                      SidebarSelection.miningRewards => const MiningRewardsPane(),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
