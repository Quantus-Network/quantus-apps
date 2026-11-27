import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_inspector.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/in_progress_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/open_proposals_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/balance_card.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/panel_resize_handle.dart';
import 'package:quantus_desktop_wallet/ui/shell/backup_reminder.dart';
import 'package:quantus_desktop_wallet/ui/shell/panel_widths.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The active account's panels: its balance; what of it is still under way
/// and, for a multisig, its open proposals, each only as tall as it needs;
/// then its activity; and, at the right, what is open of it, resizable from
/// the gap beside it. Its actions are in the top bar.
///
/// A click in the lists puts the keys there: ↑ and ↓ walk every row that
/// opens, the lists as one, Tab moves the keys into the panel at the right,
/// and Esc closes it. The panel the keys are in has the lighter border.
class AccountPane extends ConsumerStatefulWidget {
  const AccountPane({super.key});

  @override
  ConsumerState<AccountPane> createState() => _AccountPaneState();
}

class _AccountPaneState extends ConsumerState<AccountPane> {
  final _lists = FocusNode(debugLabel: 'activity lists');
  final _inspector = FocusNode(debugLabel: 'activity inspector');

  @override
  void initState() {
    super.initState();
    _lists.addListener(_onFocusChange);
    _inspector.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _lists.dispose();
    _inspector.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return ref
        .watch(activeAccountProvider)
        .when(
          loading: () => const Center(child: Loader()),
          error: (_, _) => _message(context, l10n.accountsSheetFailedLoadActiveAccount),
          data: (active) => active == null ? _message(context, l10n.homeNoActiveAccount) : _content(active),
        );
  }

  Widget _message(BuildContext context, String message) {
    return Center(
      child: Text(message, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted)),
    );
  }

  /// Every row that opens, in the order the lists show them.
  List<OpenedActivity> _openable() {
    final account = ref.read(activeAccountProvider).value?.account;
    final swapRows = [
      if (account != null)
        for (final swap in ref.read(accountSwapsProvider(account.accountId))) OpenedSwap(swap.id),
    ];
    final view = ref.read(activityViewProvider).value;
    if (view == null) return swapRows;
    OpenedActivity of(TransactionEvent tx) => switch (tx) {
      MultisigProposalEvent(:final proposal) => OpenedProposal(proposal),
      _ => OpenedTransaction(tx),
    };
    final proposals = ref.read(openProposalsViewProvider)?.value;
    return [
      ...swapRows,
      for (final tx in view.inProgress) of(tx),
      for (final pending in proposals?.proposing ?? const <PendingMultisigProposalEvent>[]) OpenedTransaction(pending),
      for (final proposal in proposals?.open ?? const <MultisigProposal>[]) OpenedProposal(proposal),
      for (final tx in view.settled) of(tx),
    ];
  }

  /// Opens the row [by] rows from the open one, or the first when none is.
  void _step(int by) {
    final rows = _openable();
    if (rows.isEmpty) return;
    final current = ref.read(openedActivityViewProvider)?.id;
    final at = rows.indexWhere((row) => row.id == current);
    final next = at < 0 ? 0 : (at + by).clamp(0, rows.length - 1);
    ref.read(openedActivityProvider.notifier).open(rows[next]);
  }

  bool get _isOpen => ref.read(openedActivityViewProvider) != null;

  KeyEventResult _onListsKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        _step(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _step(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape when _isOpen && event is KeyDownEvent:
        ref.read(openedActivityProvider.notifier).close();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.tab when _isOpen && !HardwareKeyboard.instance.isShiftPressed:
        _inspector.requestFocus();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult _onInspectorKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
    ref.read(openedActivityProvider.notifier).close();
    _lists.requestFocus();
    return KeyEventResult.handled;
  }

  Widget _content(DisplayAccount active) {
    // What was open and is no longer in the lists stays closed.
    ref.listen(openedActivityViewProvider, (_, opened) {
      if (opened != null) return;
      // After the frame: the providers that found it gone are still being
      // rebuilt in this one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (ref.read(openedActivityViewProvider) == null) ref.read(openedActivityProvider.notifier).close();
      });
    });
    final account = active.account;
    final backupWallet = ref.watch(backupReminderWalletIndexProvider);
    final view = ref.watch(activityViewProvider).value;
    final inProgress = view?.inProgress ?? const <TransactionEvent>[];
    final multisig = account is MultisigAccount ? account : null;
    final swaps = ref.watch(accountSwapsProvider(account.accountId));
    final showsInProgress = inProgress.isNotEmpty || swaps.isNotEmpty;
    final opened = ref.watch(openedActivityViewProvider);
    final inspectorWidth = ref.watch(inspectorWidthProvider);
    final inspector = ref.read(inspectorWidthProvider.notifier);

    // The keys are in the lists, in the panel that holds the open row (in
    // Activity while none is open), or in the panel at the right.
    final listsHaveKeys = _lists.hasFocus;
    final openId = opened?.id;
    final proposals = ref.watch(openProposalsViewProvider)?.value;
    final holder = openId == null
        ? ActivityPanel
        : swaps.any((swap) => swap.id == openId) || inProgress.any((tx) => tx.id == openId)
        ? InProgressPanel
        : [
            ...?proposals?.proposing.map((pending) => pending.id),
            ...?proposals?.open.map((proposal) => proposal.entityId),
          ].contains(openId)
        ? OpenProposalsPanel
        : ActivityPanel;
    bool holds(Type panel) => listsHaveKeys && holder == panel;

    // The regions take the keys without a node of their own for a screen
    // reader, which would merge what they hold.
    final lists = Focus(
      focusNode: _lists,
      includeSemantics: false,
      onKeyEvent: _onListsKey,
      child: Listener(
        onPointerDown: (_) => _lists.requestFocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // What sits over Activity takes half the column at most, or a
            // third each when both do.
            final shares = (showsInProgress ? 1 : 0) + (multisig == null ? 0 : 1);
            final limit = shares == 0 ? 0.0 : constraints.maxHeight / (shares == 1 ? 2 : 3);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BalanceCard(account: account),
                if (backupWallet != null) ...[
                  const SizedBox(height: Panel.gap),
                  BackupReminder(walletIndex: backupWallet),
                ],
                if (showsInProgress) ...[
                  const SizedBox(height: Panel.gap),
                  InProgressPanel(
                    transactions: inProgress,
                    swaps: swaps,
                    maxHeight: limit,
                    isFocused: holds(InProgressPanel),
                    rowsHaveKeys: listsHaveKeys,
                  ),
                ],
                if (multisig != null) ...[
                  const SizedBox(height: Panel.gap),
                  OpenProposalsPanel(
                    multisig: multisig,
                    maxHeight: limit,
                    isFocused: holds(OpenProposalsPanel),
                    rowsHaveKeys: listsHaveKeys,
                  ),
                ],
                const SizedBox(height: Panel.gap),
                Expanded(
                  child: ActivityPanel(isFocused: holds(ActivityPanel), rowsHaveKeys: listsHaveKeys),
                ),
              ],
            );
          },
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // As shown: it gives way to the lists in a narrow window, once the
        // sidebar has.
        final shown = shownInspectorWidth(paneWidth: constraints.maxWidth, made: inspectorWidth);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: lists),
            if (opened != null) ...[
              PanelResizeHandle(
                width: shown,
                resizes: ResizedPanel.right,
                onResize: inspector.resizeTo,
                onResizeEnd: () => unawaited(inspector.save()),
              ),
              SizedBox(
                width: shown,
                child: Focus(
                  focusNode: _inspector,
                  includeSemantics: false,
                  onKeyEvent: _onInspectorKey,
                  child: Listener(
                    onPointerDown: (_) => _inspector.requestFocus(),
                    child: ActivityInspector(isFocused: _inspector.hasFocus),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
