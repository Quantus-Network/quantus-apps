import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swap_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/utils/account_actions.dart';

/// Whether the sidebar is shown. The View menu hides and shows it.
final sidebarVisibleProvider = NotifierProvider<SidebarVisibilityNotifier, bool>(SidebarVisibilityNotifier.new);

class SidebarVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final sidebarSelectionProvider = NotifierProvider<SidebarSelectionNotifier, SidebarSelection>(
  SidebarSelectionNotifier.new,
);

class SidebarSelectionNotifier extends Notifier<SidebarSelection> {
  @override
  SidebarSelection build() => SidebarSelection.account;

  void select(SidebarSelection selection) => state = selection;
}

/// The sheet over the window, or null when there is none.
final shellSheetProvider = NotifierProvider<ShellSheetNotifier, ShellSheet?>(ShellSheetNotifier.new);

class ShellSheetNotifier extends Notifier<ShellSheet?> {
  @override
  ShellSheet? build() => null;

  /// Presents [sheet]. A sheet is modal to the window, so a request made
  /// while one is open does nothing.
  void open(ShellSheet sheet) {
    if (state != null) return;
    state = sheet;
  }

  /// Called by the shell once the sheet has left the screen.
  void closed() => state = null;
}

/// What the active account offers, for the toolbar and the Account menu alike.
final activeAccountActionsProvider = Provider<List<AccountAction>>((ref) {
  final active = ref.watch(activeAccountProvider).value;
  if (active == null) return const [];
  return accountActions(
    active,
    swapAvailable: ref.watch(remoteConfigProvider).swapAvailable,
    hasActiveSwap: ref.watch(activeSwapProvider) != null,
  );
});
