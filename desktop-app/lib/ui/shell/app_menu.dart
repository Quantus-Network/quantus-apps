import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_titles.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/utils/account_actions.dart';

/// The app's menus, defined once for every platform.
///
/// With [useNativeMenuBar] (macOS) they include the items the system supplies
/// (About, Hide, Quit, full screen, the Window menu) and shortcuts use ⌘.
/// Elsewhere those items are left out and shortcuts use Ctrl.
///
/// An item whose `onSelected` is null is disabled. The items that open a sheet
/// are disabled while [canOpenSheet] is false.
List<PlatformMenu> buildAppMenus({
  required AppLocalizations l10n,
  required bool useNativeMenuBar,
  required List<AccountAction> accountActions,
  required bool isSidebarVisible,
  required bool canOpenSheet,
  required ValueChanged<ShellSheet> onOpenSheet,
  required VoidCallback onToggleSidebar,
  required VoidCallback onCloseWindow,
}) {
  SingleActivator command(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: useNativeMenuBar, control: !useNativeMenuBar);

  VoidCallback? opens(ShellSheet sheet, {bool isEnabled = true}) =>
      canOpenSheet && isEnabled ? () => onOpenSheet(sheet) : null;

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
              shortcut: command(LogicalKeyboardKey.comma),
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
          shortcut: command(LogicalKeyboardKey.keyW),
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
                  onSelected: opens(sheetForAction(action.kind), isEnabled: action.isEnabled),
                ),
            ],
          ),
        PlatformMenuItemGroup(
          members: [PlatformMenuItem(label: l10n.desktopMenuAddAccount, onSelected: opens(ShellSheet.addAccount))],
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
              shortcut: command(LogicalKeyboardKey.keyB),
              onSelected: onToggleSidebar,
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
