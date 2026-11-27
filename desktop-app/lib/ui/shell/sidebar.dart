import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_marks_providers.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/account_balance.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/sidebar_order_provider.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_context_menus.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_note_text.dart';
import 'package:quantus_desktop_wallet/ui/accounts/add_account_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/account_balance_text.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_account_badge.dart';
import 'package:quantus_desktop_wallet/ui/components/inline_name_field.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_desktop_wallet/utils/wallet_names.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/account_menu.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';
import 'package:wallet_core/utils/hidden_amount.dart';

/// The Accounts panel: the accounts grouped by wallet, then the multisigs
/// under a heading of their own, and Settings and Add Account at the foot. Choosing an account
/// makes it the active account. The shell sets its width
/// ([sidebarWidthProvider]).
///
/// The groups keep the order they were put in ([sidebarGroupsProvider])
/// whichever account is active, so a row never moves when it is clicked.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key, required this.onNewWallet});

  /// Creates another wallet, as the Add Account menu's New Wallet asks: the
  /// shell's, as the wallet's Encrypted account is added on its ref.
  final VoidCallback onNewWallet;

  /// The line that shows where a heading being dragged would land.
  static const dropLineKey = Key('sidebar-drop-line');

  /// The size of the icon before a row that is not an account.
  static const double _iconSize = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;

    return Panel(
      title: l10n.accountsSheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              children: [..._accounts(context, ref, l10n)],
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
                Builder(
                  builder: (row) => SidebarRow(
                    title: l10n.accountsSheetAddAccount,
                    isSecondary: true,
                    leading: const QuantusIcon(QuantusIcons.plus, size: _iconSize),
                    onTap: () => _openAddMenu(row, ref),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pulls down what can be added from the Add Account row at [row].
  void _openAddMenu(BuildContext row, WidgetRef ref) {
    final items = addAccountMenuItems(
      ref.read(l10nProvider),
      ref.read(softwareWalletsProvider),
      ref.read(accountManagerProvider),
      onNewWallet: onNewWallet,
      offersColdWallets: ref.read(remoteConfigProvider).enableKeystoneHardwareWallet,
      offersMultisigs: ref.read(remoteConfigProvider).enableMultisig,
      canCreateMultisig: ref.read(multisigCreatorProvider) != null,
    );
    final box = row.findRenderObject()! as RenderBox;
    unawaited(showPullDownMenu(row, anchor: box.localToGlobal(Offset.zero) & box.size, items: items));
  }

  List<Widget> _accounts(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
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

    final groups = ref.watch(sidebarGroupsProvider) ?? const [];
    if (groups.isEmpty) return [_message(context, l10n.accountsSheetNoAccountsFound)];
    // Each where it will be once the chain has it: after the multisigs.
    final creating = ref.watch(creatingMultisigsProvider);

    final selectedAccountId = active.value?.account.accountId;
    // Keyed: a group opening or closing moves what is below it, and a row or
    // heading keeps what it holds, a name being typed or a failure, as it moves.
    Widget row(DisplayAccount display) => _AccountRow(
      key: ValueKey('sidebar-account-${display.account.accountId}'),
      display: display,
      isSelected: display.account.accountId == selectedAccountId,
    );
    final open = ref.watch(openWalletsProvider);
    final activeWallet = ref.watch(activeRowWalletIndexProvider);
    final multisigsOpen = ref.watch(multisigsOpenProvider);
    final renaming = ref.watch(sidebarRenameProvider);

    // Each group in a block of its own, keyed, so a group moved keeps what
    // its heading and rows hold.
    return [
      for (final group in groups)
        switch (group) {
          SidebarWallet(:final wallet) => _GroupBlock(
            key: ValueKey('sidebar-group-${group.orderKey}'),
            groupKey: group.orderKey,
            name: walletDisplayName(l10n, wallet, ref.watch(walletNameProvider(wallet.walletIndex))),
            // A heading being renamed takes the pointer for its text.
            canDrag: renaming != RenameWallet(wallet.walletIndex),
            heading: _WalletHeader(
              key: ValueKey('sidebar-wallet-${wallet.walletIndex}'),
              wallet: wallet,
              isOpen: open.contains(wallet.walletIndex),
              holdsActiveAccount: wallet.walletIndex == activeWallet,
            ),
            rows: [
              if (open.contains(wallet.walletIndex))
                for (final account in walletAccountsInOrder(wallet)) row(account),
            ],
          ),
          SidebarMultisigs(:final multisigs) => _GroupBlock(
            key: ValueKey('sidebar-group-${group.orderKey}'),
            groupKey: group.orderKey,
            name: l10n.desktopSidebarMultisigs,
            canDrag: true,
            heading: _MultisigsHeader(
              key: const ValueKey('sidebar-multisigs'),
              multisigs: multisigs,
              count: multisigs.length + creating.length,
              isOpen: multisigsOpen,
              holdsActiveAccount: ref.watch(activeIsMultisigProvider),
            ),
            rows: [
              if (multisigsOpen) ...[
                for (final multisig in multisigs) row(MultisigDisplayAccount(multisig)),
                for (final multisig in creating)
                  _CreatingRow(key: ValueKey('sidebar-creating-${multisig.accountId}'), multisig: multisig),
              ],
            ],
          ),
        },
    ];
  }

  Widget _message(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: Text(message, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted)),
    );
  }
}

/// A group of the sidebar: its [heading], which can be dragged onto another
/// group to move the group before or after it, and its [rows]. While a
/// heading is dragged over the group, a line shows where it would land.
class _GroupBlock extends ConsumerStatefulWidget {
  const _GroupBlock({
    super.key,
    required this.groupKey,
    required this.name,
    required this.canDrag,
    required this.heading,
    required this.rows,
  });

  /// The group's [SidebarGroup.orderKey].
  final String groupKey;

  /// The group's name, drawn on the heading as it is dragged.
  final String name;
  final bool canDrag;
  final Widget heading;
  final List<Widget> rows;

  @override
  ConsumerState<_GroupBlock> createState() => _GroupBlockState();
}

class _GroupBlockState extends ConsumerState<_GroupBlock> {
  /// Where a heading dragged over the group would land: after it, before it,
  /// or nowhere (null).
  bool? _landsAfter;

  bool _isDragged = false;

  /// Whether a heading dropped at [offset] (its pointer, globally) lands
  /// after this group: over its lower half.
  bool _isAfter(Offset offset) {
    final box = context.findRenderObject()! as RenderBox;
    return box.globalToLocal(offset).dy > box.size.height / 2;
  }

  void _hover(DragTargetDetails<String> details) {
    final after = _isAfter(details.offset);
    final lands = ref.read(sidebarGroupMoverProvider).wouldPlace(details.data, beside: widget.groupKey, after: after);
    final next = lands ? after : null;
    if (next != _landsAfter) setState(() => _landsAfter = next);
  }

  void _drop(DragTargetDetails<String> details) {
    setState(() => _landsAfter = null);
    ref.read(sidebarGroupMoverProvider).place(details.data, beside: widget.groupKey, after: _isAfter(details.offset));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final landsAfter = _landsAfter;
    final heading = LayoutBuilder(
      builder: (context, constraints) => Draggable<String>(
        data: widget.groupKey,
        maxSimultaneousDrags: widget.canDrag ? 1 : 0,
        // The pointer is where the heading lands, so the image hangs from it.
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: _DraggedHeading(name: widget.name, width: constraints.maxWidth),
        onDragStarted: () => setState(() => _isDragged = true),
        onDragEnd: (_) => setState(() => _isDragged = false),
        child: widget.heading,
      ),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.groupKey,
      onMove: _hover,
      onLeave: (_) => setState(() => _landsAfter = null),
      onAcceptWithDetails: _drop,
      builder: (context, _, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: _isDragged ? 0.4 : 1,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heading, ...widget.rows]),
          ),
          if (landsAfter != null)
            Positioned(
              key: Sidebar.dropLineKey,
              left: 6,
              right: 6,
              top: landsAfter ? null : 2,
              bottom: landsAfter ? -1 : null,
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(color: colors.accentFlare, borderRadius: BorderRadius.circular(1)),
              ),
            ),
        ],
      ),
    );
  }
}

/// A group's heading as it is dragged: its name in capitals on a raised strip
/// [width] wide, the sidebar's.
class _DraggedHeading extends StatelessWidget {
  const _DraggedHeading({required this.name, required this.width});

  final String name;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: context.radiusV3.smBorder,
          border: Border.all(color: colors.borderHairline),
        ),
        child: Text(
          name.toUpperCase(),
          style: text.caption.copyWith(color: colors.textMuted2, fontWeight: FontWeight.w500, letterSpacing: 0.8),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// A wallet's heading, which opens and closes the wallet, as the HIG groups a
/// long sidebar. The wallet of the active account stays open, so it is always
/// clear which wallet that account is in: its heading is not a control.
class _WalletHeader extends ConsumerStatefulWidget {
  const _WalletHeader({super.key, required this.wallet, required this.isOpen, required this.holdsActiveAccount});

  final WalletGroup wallet;
  final bool isOpen;
  final bool holdsActiveAccount;

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

  void _toggle() {
    // A Control-click opens the menu instead.
    if (ContextMenuRegion.isControlClick) return;
    ref.read(keptOpenWalletsProvider.notifier).toggle(widget.wallet.walletIndex);
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
        : _heading(name, l10n);
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

  /// The name, with the wallet's chevron and, while it is closed, how many
  /// accounts it holds and what they hold together.
  Widget _heading(String name, AppLocalizations l10n) => _GroupHeading(
    name: name,
    count: widget.wallet.accountCount,
    countDescription: l10n.desktopWalletAccountCount(widget.wallet.accountCount),
    total: widget.isOpen ? null : _groupTotal(ref, walletAccountsInOrder(widget.wallet).map((d) => d.account)),
    isOpen: widget.isOpen,
    isControl: !widget.holdsActiveAccount,
    onToggle: _toggle,
  );
}

/// The multisigs' heading, which opens and closes them as a wallet's does,
/// and stays open while one of them is the active account. Its name is
/// fixed, so it is always clear which group holds the multisigs.
class _MultisigsHeader extends ConsumerWidget {
  const _MultisigsHeader({
    super.key,
    required this.multisigs,
    required this.count,
    required this.isOpen,
    required this.holdsActiveAccount,
  });

  /// The multisigs the chain has, whose balances its total adds up.
  final List<MultisigAccount> multisigs;

  /// The multisigs, and those being created.
  final int count;
  final bool isOpen;
  final bool holdsActiveAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return MultisigsContextMenu(
      child: _GroupHeading(
        name: l10n.desktopSidebarMultisigs,
        count: count,
        countDescription: l10n.desktopWalletAccountCount(count),
        total: isOpen ? null : _groupTotal(ref, multisigs),
        isOpen: isOpen,
        isControl: !holdsActiveAccount,
        onToggle: () {
          // A Control-click opens the menu instead.
          if (ContextMenuRegion.isControlClick) return;
          ref.read(keptOpenMultisigsProvider.notifier).toggle();
        },
      ),
    );
  }
}

/// What [accounts] hold together, as a closed group's heading shows it and as
/// a screen reader hears it: masked, and heard as hidden, while balances are
/// hidden.
({String shown, String heard}) _groupTotal(WidgetRef ref, Iterable<BaseAccount> accounts) {
  final l10n = ref.watch(l10nProvider);
  if (ref.watch(isBalanceHiddenProvider)) return (shown: hiddenAmountText, heard: l10n.desktopAmountHidden);
  final line = balanceLine(l10n, ref.watch(numberFormattingServiceProvider), accountsTotalWith(ref.watch, accounts));
  return (shown: line, heard: line);
}

/// A group's heading in the sidebar: its [name] in capitals with a chevron
/// when it is a control, and [count] while it is closed, with the group's
/// [total] on a line under the name. [onToggle] opens or closes the group
/// where it [isControl].
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({
    required this.name,
    required this.count,
    required this.countDescription,
    required this.total,
    required this.isOpen,
    required this.isControl,
    required this.onToggle,
  });

  final String name;
  final int count;

  /// [count] as a screen reader hears it.
  final String countDescription;

  /// What the group's accounts hold together, in words, shown while it is
  /// closed, and as a screen reader hears it.
  final ({String shown, String heard})? total;
  final bool isOpen;
  final bool isControl;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final radius = context.radiusV3.smBorder;
    final quiet = text.caption.copyWith(color: colors.textMuted2);

    // Drawn in capitals, which is a look and not the name: a screen reader
    // gets the name as it is written.
    return Semantics(
      label: name,
      value: isOpen ? null : [countDescription, ?total?.heard].join(', '),
      button: isControl,
      expanded: isOpen,
      onTap: isControl ? onToggle : null,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: isControl ? onToggle : null,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.toUpperCase(),
                          style: quiet.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.8),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!isOpen) ...[Text('$count', style: quiet), const SizedBox(width: 7)],
                      if (isControl)
                        Icon(
                          isOpen ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                          size: 11,
                          color: colors.textMuted2,
                        ),
                    ],
                  ),
                  if (total case final total? when !isOpen)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(total.shown, style: quiet, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A multisig the chain has yet to confirm: its name and a moving status. It
/// is not an account yet, so nothing selects it, and it has no menu.
class _CreatingRow extends ConsumerWidget {
  const _CreatingRow({super.key, required this.multisig});

  final MultisigAccount multisig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SidebarRow(
      title: multisig.name,
      leading: DesktopAccountBadge(account: multisig, size: _AccountRow._badgeSize),
      subtitle: TerminalBusyLine(label: ref.watch(l10nProvider).multisigCreateCreatingButton),
      onTap: null,
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({super.key, required this.display, required this.isSelected});

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
      // A Control-click opens the menu instead; a click while the name is
      // being typed over only ends the typing.
      onTap: () {
        if (ContextMenuRegion.isControlClick || renaming) return;
        ref.read(sidebarNavigatorProvider).showAccount(display);
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
