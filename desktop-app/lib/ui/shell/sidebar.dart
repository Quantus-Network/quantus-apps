import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_marks_providers.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_context_menus.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_note_text.dart';
import 'package:quantus_desktop_wallet/ui/components/account_balance_text.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/components/inline_name_field.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_desktop_wallet/utils/wallet_names.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/account_menu.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// The Accounts panel: the accounts grouped by wallet, with Mining Rewards
/// beneath them, and Settings and Add Account at the foot. Choosing an account
/// makes it the active account. The shell sets its width
/// ([sidebarWidthProvider]).
///
/// Wallets keep one order (software wallets by index, then Keystone) whichever
/// account is active, so a row never moves when it is clicked.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  /// The size of the icon before a row that is not an account.
  static const double _iconSize = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final selection = ref.watch(sidebarSelectionProvider);

    return Panel(
      title: l10n.accountsSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: [
                ..._accounts(context, ref, l10n, selection),
                const SizedBox(height: 10),
                const MenuDivider(),
                const SizedBox(height: 6),
                SidebarRow(
                  title: l10n.settingsMiningRewards,
                  isSecondary: true,
                  leading: Icon(Icons.hardware_outlined, size: _iconSize, color: colors.textMuted),
                  isSelected: selection == SidebarSelection.miningRewards,
                  onTap: () => ref.read(sidebarSelectionProvider.notifier).select(SidebarSelection.miningRewards),
                ),
              ],
            ),
          ),
          const MenuDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 2,
              children: [
                SidebarRow(
                  title: l10n.settingsTitle,
                  isSecondary: true,
                  leading: Icon(CupertinoIcons.gear, size: _iconSize, color: colors.textMuted),
                  onTap: () => ref.read(shellSheetProvider.notifier).open(ShellSheet.settings),
                ),
                SidebarRow(
                  title: l10n.accountsSheetAddAccount,
                  isSecondary: true,
                  leading: const QuantusIcon(QuantusIcons.plus, size: _iconSize),
                  onTap: () => ref.read(shellSheetProvider.notifier).open(ShellSheet.addAccount),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _accounts(BuildContext context, WidgetRef ref, AppLocalizations l10n, SidebarSelection selection) {
    final accounts = ref.watch(accountsProvider);
    final multisigs = ref.watch(multisigAccountsProvider);
    final active = ref.watch(activeAccountProvider);

    if (accounts.isLoading || multisigs.isLoading || active.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Loader()),
        ),
      ];
    }
    if (accounts.hasError || multisigs.hasError) return [_message(context, l10n.accountsSheetFailedLoadAccounts)];
    if (active.hasError) return [_message(context, l10n.accountsSheetFailedLoadActiveAccount)];

    final grouping = groupWallets(accounts: accounts.value ?? [], multisigs: multisigs.value ?? []);
    if (grouping.wallets.isEmpty && grouping.standaloneMultisigs.isEmpty) {
      return [_message(context, l10n.accountsSheetNoAccountsFound)];
    }

    final selectedAccountId = selection == SidebarSelection.account ? active.value?.account.accountId : null;
    Widget row(DisplayAccount display) =>
        _AccountRow(display: display, isSelected: display.account.accountId == selectedAccountId);

    return [
      for (final wallet in grouping.wallets) ...[
        _WalletHeader(wallet: wallet),
        for (final account in walletAccountsInOrder(wallet)) row(account),
      ],
      if (grouping.standaloneMultisigs.isNotEmpty) ...[
        if (grouping.wallets.isNotEmpty) ...[
          const SizedBox(height: 12),
          const MenuDivider(),
          const SizedBox(height: 12),
        ],
        for (final multisig in grouping.standaloneMultisigs) row(MultisigDisplayAccount(multisig)),
      ],
    ];
  }

  Widget _message(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: Text(message, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted)),
    );
  }
}

class _WalletHeader extends ConsumerStatefulWidget {
  const _WalletHeader({required this.wallet});

  final WalletGroup wallet;

  @override
  ConsumerState<_WalletHeader> createState() => _WalletHeaderState();
}

class _WalletHeaderState extends ConsumerState<_WalletHeader> {
  /// Why the name typed over the heading was not kept, shown under it for a
  /// while, as an account's note shows on its row.
  String? _error;
  Timer? _clearError;

  RenameWallet get _target => RenameWallet(widget.wallet.walletIndex);

  // Held for [_keep], which can run once the heading is gone.
  late final AccountManager _manager;
  late final SidebarRenameNotifier _renames;

  @override
  void initState() {
    super.initState();
    _manager = ref.read(accountManagerProvider);
    _renames = ref.read(sidebarRenameProvider.notifier);
  }

  @override
  void dispose() {
    _clearError?.cancel();
    super.dispose();
  }

  Future<String?> _keep(String entered) async {
    final target = _target;
    if (!_manager.isMounted) return null;
    try {
      await _manager.renameWallet(target.walletIndex, entered);
    } catch (e) {
      quantusPrint('Renaming wallet ${target.walletIndex} failed: $e');
      if (mounted) _showError(ref.read(l10nProvider).desktopWalletRenameFailed);
    } finally {
      _renames.end(target);
    }
    return null;
  }

  void _showError(String message) {
    _clearError?.cancel();
    setState(() => _error = message);
    _clearError = Timer(AccountNoteNotifier.failureShownFor, () {
      if (mounted) setState(() => _error = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final name = walletDisplayName(l10n, widget.wallet, ref.watch(walletNameProvider(widget.wallet.walletIndex)));
    final renaming = ref.watch(sidebarRenameProvider) == _target;
    final error = _error;

    final Widget title = renaming
        ? Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
            child: InlineNameField(
              name: name,
              autofocus: true,
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: text.caption.copyWith(color: colors.textContent, fontWeight: FontWeight.w500),
              onKeep: _keep,
              onCancel: () => ref.read(sidebarRenameProvider.notifier).end(_target),
            ),
          )
        // Drawn in capitals, which is a look and not the name: a screen
        // reader gets the name as it is written.
        : Semantics(
            label: name,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
              child: Text(
                name.toUpperCase(),
                style: text.caption.copyWith(color: colors.textMuted2, fontWeight: FontWeight.w500, letterSpacing: 0.8),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
    // One column whether or not an error shows under the title, so the title,
    // and a name being typed in it, stays as it is when the error comes or goes.
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Semantics(
              liveRegion: true,
              child: Text(error, style: text.caption.copyWith(color: colors.semanticEmber)),
            ),
          ),
      ],
    );
    return WalletContextMenu(wallet: widget.wallet, child: heading);
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.display, required this.isSelected});

  final DisplayAccount display;
  final bool isSelected;

  static const double _badgeSize = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = display.account;
    // A note about the account ("Address copied") shows in its balance's place.
    final note = ref.watch(accountNoteProvider);
    final l10n = ref.watch(l10nProvider);
    final mark = ref.watch(accountMarksProvider)[account.accountId] ?? const AccountMark();
    final marked = [
      if (mark.inProgress > 0) l10n.desktopMarksInProgress(mark.inProgress),
      if (mark.waitingForSignature > 0) l10n.desktopMarksWaitingForSignature(mark.waitingForSignature),
    ];
    final badge = DesktopAccountBadge(account: account, size: _badgeSize, count: mark.count);
    final renaming = ref.watch(sidebarRenameProvider) == RenameAccount(account.accountId);

    final row = SidebarRow(
      title: account.name,
      titleEditor: renaming
          ? InlineNameField(
              name: account.name,
              autofocus: true,
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: context.themeTextV3.bodyEmphasis.copyWith(color: context.colorsV3.textContent),
              onKeep: _keeper(ref, account),
              onCancel: () => ref.read(sidebarRenameProvider.notifier).end(RenameAccount(account.accountId)),
            )
          : null,
      isSelected: isSelected,
      // The count on the badge, as a screen reader hears it.
      leading: marked.isEmpty ? badge : Semantics(label: marked.join(', '), child: badge),
      subtitle: note != null && note.accountId == account.accountId
          ? AccountNoteText(note: note)
          : AccountBalanceText(
              account: account,
              style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted),
            ),
      trailing: display is MultisigDisplayAccount ? QuantusBadge(label: ref.watch(l10nProvider).multisigTag) : null,
      // A Control-click opens the menu instead; a click while the name is
      // being typed over only ends the typing.
      onTap: () {
        if (ContextMenuRegion.isControlClick || renaming) return;
        ref.read(sidebarSelectionProvider.notifier).showAccount(display);
      },
    );
    return AccountContextMenu(account: account, child: row);
  }

  /// Keeps the name typed over the row. One that is not kept says why on the
  /// row, in its balance's place. What it uses is taken now: it can run once
  /// the row is gone, as when the sidebar is hidden while the name is typed.
  static Future<String?> Function(String entered) _keeper(WidgetRef ref, BaseAccount account) {
    final l10n = ref.read(l10nProvider);
    final notes = ref.read(accountNoteProvider.notifier);
    final renames = ref.read(sidebarRenameProvider.notifier);
    final manager = ref.read(accountManagerProvider);
    AccountNote failure(String message) => AccountNote(accountId: account.accountId, message: message, isError: true);
    return (entered) async {
      if (!manager.isMounted) return null;
      try {
        if (await manager.rename(account, entered) is NameBlank) notes.show(failure(l10n.editAccountNameEmpty));
      } catch (e) {
        quantusPrint('Renaming ${account.accountId} failed: $e');
        notes.show(failure(l10n.editAccountRenameFailed));
      } finally {
        renames.end(RenameAccount(account.accountId));
      }
      return null;
    };
  }
}
