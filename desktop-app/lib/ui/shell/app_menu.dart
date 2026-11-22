import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart' show SoftwareWallet;
import 'package:quantus_desktop_wallet/ui/accounts/account_menu_entries.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_titles.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/utils/account_actions.dart';

/// The app's menus, defined once for every platform.
///
/// With [useNativeMenuBar] (macOS) they include the items the system supplies
/// (About, Hide, Quit, full screen, the Window menu). Elsewhere those items
/// are left out. The items' keys are [shortcuts]; with none, as while a new
/// shortcut is being recorded, no item has keys.
///
/// An item whose `onSelected` is null is disabled. The items that open a sheet
/// are disabled while [canOpenSheet] is false, the sidebar item while
/// [onToggleSidebar] is null, those that change what the sidebar has selected
/// while [onShowAccount] and [onMoveInSidebar] are, and Refresh while
/// [onRefresh] is.
///
/// The Account menu offers [accountItems], the active account's own items
/// ([accountMenuEntries]), after its actions; they are disabled with the
/// items that open a sheet.
///
/// New Account adds an account to one of [newAccountWallets]: a plain item
/// with one, a submenu with several. A chosen item adds to the wallet it names
/// ([onNewAccount]). Its shortcut sits on [newAccountShortcutWallet]; with
/// none, no item has it. In the menus that answer a key press,
/// [onNewAccountByKey] is given and that item acts on it instead, for the
/// wallet of the account active when its turn comes. It is disabled with the
/// items that open a sheet.
///
/// The Account menu ends with [accounts], which are in the sidebar's order:
/// the first nine have a number to be reached by ([ShortcutBindings.account]).
List<PlatformMenu> buildAppMenus({
  required AppLocalizations l10n,
  required bool useNativeMenuBar,
  required List<AccountAction> accountActions,
  required List<AccountMenuEntry?> accountItems,
  required List<SoftwareWallet> newAccountWallets,
  required int? newAccountShortcutWallet,
  required ValueChanged<int> onNewAccount,
  required VoidCallback? onNewAccountByKey,
  required List<DisplayAccount> accounts,
  required ShortcutBindings? shortcuts,
  required bool isSidebarVisible,
  required bool canOpenSheet,
  required ValueChanged<ShellSheet> onOpenSheet,
  required ValueChanged<DisplayAccount>? onShowAccount,
  required ValueChanged<int>? onMoveInSidebar,
  required VoidCallback? onToggleSidebar,
  required VoidCallback? onRefresh,
  required VoidCallback onCloseWindow,
}) {
  SingleActivator? keysOf(AppCommand command) => shortcuts?[command]?.activator;

  VoidCallback? opens(ShellSheet sheet, {bool isEnabled = true}) =>
      canOpenSheet && isEnabled ? () => onOpenSheet(sheet) : null;

  SingleActivator? shortcutOf(AccountActionKind action) => switch (action) {
    AccountActionKind.receive => keysOf(AppCommand.receive),
    AccountActionKind.send => keysOf(AppCommand.send),
    AccountActionKind.propose => keysOf(AppCommand.propose),
    // Its sheet is not built yet.
    AccountActionKind.swap => null,
  };

  PlatformMenuItem newAccountItem(String label, int walletIndex) {
    final hasShortcut = walletIndex == newAccountShortcutWallet;
    return PlatformMenuItem(
      label: label,
      shortcut: hasShortcut ? keysOf(AppCommand.addAccount) : null,
      onSelected: !canOpenSheet ? null : (hasShortcut ? onNewAccountByKey : null) ?? () => onNewAccount(walletIndex),
    );
  }

  PlatformMenuItemGroup provided(List<PlatformProvidedMenuItemType> types) =>
      PlatformMenuItemGroup(members: [for (final type in types) PlatformProvidedMenuItem(type: type)]);

  return [
    PlatformMenu(
      label: appTitle,
      menus: [
        if (useNativeMenuBar) provided(const [PlatformProvidedMenuItemType.about]),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: l10n.desktopMenuSettings,
              shortcut: shortcuts?.settings.activator,
              onSelected: opens(ShellSheet.settings),
            ),
          ],
        ),
        if (useNativeMenuBar) ...[
          provided(const [PlatformProvidedMenuItemType.servicesSubmenu]),
          provided(const [
            PlatformProvidedMenuItemType.hide,
            PlatformProvidedMenuItemType.hideOtherApplications,
            PlatformProvidedMenuItemType.showAllApplications,
          ]),
          provided(const [PlatformProvidedMenuItemType.quit]),
        ],
      ],
    ),
    PlatformMenu(
      label: l10n.desktopMenuFile,
      menus: [
        PlatformMenuItem(
          label: l10n.desktopMenuCloseWindow,
          shortcut: shortcuts?.closeWindow.activator,
          onSelected: onCloseWindow,
        ),
      ],
    ),
    PlatformMenu(
      label: l10n.desktopMenuAccount,
      menus: [
        if (accountActions.isNotEmpty)
          PlatformMenuItemGroup(
            members: [
              for (final action in accountActions)
                PlatformMenuItem(
                  label: sheetTitle(l10n, sheetForAction(action.kind)),
                  shortcut: shortcutOf(action.kind),
                  onSelected: opens(sheetForAction(action.kind), isEnabled: action.isEnabled),
                ),
            ],
          ),
        if (accountItems.nonNulls.isNotEmpty)
          PlatformMenuItemGroup(
            members: [
              for (final item in accountItems.nonNulls)
                PlatformMenuItem(
                  label: item.label,
                  shortcut: switch (item.command) {
                    final command? => keysOf(command),
                    null => null,
                  },
                  onSelected: canOpenSheet ? item.onSelected : null,
                ),
            ],
          ),
        PlatformMenuItemGroup(
          members: [
            switch (newAccountWallets) {
              // Before there is a wallet to add to.
              [] => PlatformMenuItem(label: l10n.desktopMenuNewAccount),
              [final wallet] => newAccountItem(l10n.desktopMenuNewAccount, wallet.walletIndex),
              _ => PlatformMenu(
                label: l10n.desktopMenuNewAccount,
                menus: [for (final wallet in newAccountWallets) newAccountItem(wallet.name, wallet.walletIndex)],
              ),
            },
          ],
        ),
        if (accounts.isNotEmpty)
          PlatformMenuItemGroup(
            members: [
              for (final (index, account) in accounts.indexed)
                PlatformMenuItem(
                  label: account.account.name,
                  shortcut: shortcuts?.account(index)?.activator,
                  onSelected: onShowAccount == null ? null : () => onShowAccount(account),
                ),
            ],
          ),
      ],
    ),
    PlatformMenu(
      label: l10n.desktopMenuView,
      menus: [
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: isSidebarVisible ? l10n.desktopMenuHideSidebar : l10n.desktopMenuShowSidebar,
              shortcut: keysOf(AppCommand.toggleSidebar),
              onSelected: onToggleSidebar,
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: l10n.desktopMenuNextSidebarItem,
              shortcut: keysOf(AppCommand.nextSidebarItem),
              onSelected: onMoveInSidebar == null ? null : () => onMoveInSidebar(1),
            ),
            PlatformMenuItem(
              label: l10n.desktopMenuPreviousSidebarItem,
              shortcut: keysOf(AppCommand.previousSidebarItem),
              onSelected: onMoveInSidebar == null ? null : () => onMoveInSidebar(-1),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            PlatformMenuItem(
              label: l10n.desktopMenuRefresh,
              shortcut: keysOf(AppCommand.refresh),
              onSelected: onRefresh,
            ),
          ],
        ),
        if (useNativeMenuBar) provided(const [PlatformProvidedMenuItemType.toggleFullScreen]),
      ],
    ),
    if (useNativeMenuBar)
      PlatformMenu(
        label: l10n.desktopMenuWindow,
        menus: [
          provided(const [PlatformProvidedMenuItemType.minimizeWindow, PlatformProvidedMenuItemType.zoomWindow]),
          provided(const [PlatformProvidedMenuItemType.arrangeWindowsInFront]),
        ],
      ),
  ];
}
