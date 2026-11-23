import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/activity/inspector_parts.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/notice_box.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/summary_row.dart';
import 'package:quantus_desktop_wallet/ui/components/swap_token_mark.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/swap/swap_progress.dart';
import 'package:wallet_core/utils/account_actions.dart';
import 'package:wallet_core/utils/explorer_url.dart';

/// The swap being followed, in the panel at the window's right: where to
/// send the deposit while one made from outside the app is awaited; then its
/// steps and its terms; and at the end what arrived, or how it ended without
/// paying out.
///
/// Closing the panel leaves the swap followed. It is put away by Done, by
/// Cancel Swap before its deposit is sent, or by Stop tracking, which asks
/// first: the swap carries on at 1Click.
class SwapDetail extends ConsumerStatefulWidget {
  const SwapDetail({super.key});

  /// The button that confirms Stop tracking.
  static const confirmStopKey = Key('swap-confirm-stop');
  static const startNewKey = Key('swap-start-new');

  @override
  ConsumerState<SwapDetail> createState() => _SwapDetailState();
}

class _SwapDetailState extends ConsumerState<SwapDetail> {
  /// Whether Stop tracking was pressed, and is waiting to be confirmed.
  bool _asksToStop = false;

  /// Puts [swap] away: it is no longer followed, and the panel closes.
  void _putAway(ActiveSwap swap) {
    ref.read(openedActivityProvider.notifier).close();
    unawaited(ref.read(activeSwapsProvider.notifier).remove(swap.id));
  }

  /// Puts [swap] away and opens the Swap sheet on the active account, for
  /// the swap to be tried again.
  Future<void> _startNew(ActiveSwap swap) async {
    final sheets = ref.read(shellSheetProvider.notifier);
    ref.read(openedActivityProvider.notifier).close();
    await ref.read(activeSwapsProvider.notifier).remove(swap.id);
    await sheets.open(ShellSheet.swap);
  }

  /// Whether the active account could start a swap once this one is put
  /// away: the sheet opens on that account, whichever the swap was from.
  bool _canStartNew() {
    final active = ref.watch(activeAccountProvider).value;
    if (active == null) return false;
    return accountActions(
      active,
      swapAvailable: ref.watch(remoteConfigProvider.select((config) => config.swapAvailable)),
      hasActiveSwap: false,
    ).any((action) => action.kind == AccountActionKind.swap && action.isEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final swap = ref.watch(followedSwapProvider);
    if (swap == null) throw StateError("The swap's panel was drawn with no swap followed.");
    // Drawn again each second while the swap runs: its clock, and the moment
    // an awaited deposit's window closes.
    final now = ref.watch(swapClockProvider).value ?? clock.now();
    final page = _Page(
      context: context,
      l10n: ref.watch(l10nProvider),
      fmt: ref.watch(numberFormattingServiceProvider),
      swap: swap,
      now: now,
      preflight: ref.watch(swapPreflightProvider) != null,
      account: ref.watch(ownAccountsByAddressProvider)[swap.accountId],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (swapProgressViewOf(swap, now)) {
        SwapProgressView.inProgress => _underWay(page),
        SwapProgressView.deposit => _deposit(page),
        SwapProgressView.complete => _complete(page),
        SwapProgressView.failed => _ended(page, expired: false),
        SwapProgressView.expired => _ended(page, expired: true),
      },
    );
  }

  /// [buttons] at their own widths, side by side while there is room and one
  /// under the other when there is not.
  Widget _buttons(List<Widget> buttons, {double spacing = 10}) => Wrap(
    spacing: spacing,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [for (final button in buttons) UnconstrainedBox(child: button)],
  );

  Widget _attribution(_Page page) => Text(
    page.l10n.desktopSwapPoweredByNearIntents,
    style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted2),
  );

  /// Opens the deposit's transaction in the explorer; none where the app
  /// sent no deposit.
  Widget? _viewDeposit(_Page page) {
    final hash = page.swap.depositTxHash;
    if (hash == null) return null;
    return ToolbarAction.symbol(
      symbol: CupertinoIcons.arrow_up_right_square,
      label: page.l10n.desktopSwapViewDeposit,
      onPressed: () => unawaited(ref.read(openExternalUrlProvider)(Uri.parse(explorerUrl('transactions/$hash')))),
    );
  }

  /// Why the status cannot be checked, with a way to ask again; nothing
  /// while it can.
  List<Widget> _pollError(_Page page) {
    final error = page.swap.isFinal ? null : page.swap.pollError;
    if (error == null) return const [];
    final colors = context.colorsV3;
    return [
      const SizedBox(height: 12),
      NoticeBox(
        tone: colors.semanticSand,
        symbol: CupertinoIcons.exclamationmark_triangle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              page.l10n.swapProgressStatusUnavailable(error),
              style: context.themeTextV3.body.copyWith(color: colors.textContent),
            ),
            ToolbarActionRow(
              edge: ToolbarActionEdge.leading,
              children: [
                ToolbarAction.symbol(
                  symbol: CupertinoIcons.arrow_clockwise,
                  label: page.l10n.commonRetry,
                  onPressed: () => unawaited(ref.read(activeSwapsProvider.notifier).refresh()),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _underWay(_Page page) {
    final l10n = page.l10n;
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final swap = page.swap;
    final quote = swap.order.quote;
    final receiver = page.paysOutside ? l10n.desktopSwapTheRecipient : swap.accountName;
    final steps = swapStepLabels(l10n, quote, receiver, byHand: swap.depositByHand);
    final stage = swapStage(swap.order, depositByHand: swap.depositByHand);
    final viewDeposit = _viewDeposit(page);

    return [
      inspectorStatusLine(
        context,
        // Waiting has a part that moves, unless the system asks for none.
        mark: MediaQuery.disableAnimationsOf(context)
            ? null
            : TerminalSpinner(
                style: inspectorCapsStyle(context, color: colors.semanticGlacier).copyWith(letterSpacing: 0),
              ),
        label: l10n.activityDetailStatusInProcess,
        color: colors.semanticGlacier,
        after: formatSwapElapsed(swap.elapsedAt(page.now)),
      ),
      const SizedBox(height: 14),
      inspectorHeadline(context, page.paid),
      const SizedBox(height: 10),
      Text(page.forWhat, style: text.body.copyWith(color: colors.textContent)),
      const SizedBox(height: 24),
      ...page.receiver(),
      const SizedBox(height: 22),
      for (final (i, step) in steps.indexed)
        TerminalLine(
          name: step,
          status: i < stage ? '[OK]' : null,
          statusColor: i == stage ? colors.accentFlare : null,
          isBusy: i == stage,
          isDim: i > stage,
        ),
      ..._pollError(page),
      if (swap.overdue(page.now)) ...[
        const SizedBox(height: 12),
        NoticeBox(
          tone: colors.semanticSand,
          symbol: CupertinoIcons.clock,
          child: Text(
            l10n.swapProgressOverdue(swap.depositByHand ? quote.refundAddress : swap.accountName),
            style: text.body.copyWith(color: colors.textContent),
          ),
        ),
      ],
      const SizedBox(height: 14),
      const MenuDivider(),
      const SizedBox(height: 4),
      ...page.terms(),
      const SizedBox(height: 16),
      if (_asksToStop)
        NoticeBox(
          tone: colors.semanticSand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.swapStopTrackingConfirmTitle, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
              const SizedBox(height: 6),
              Text(l10n.swapStopTrackingConfirmBody, style: text.body.copyWith(color: colors.textContent)),
              const SizedBox(height: 12),
              _buttons([
                SheetButton(
                  label: l10n.commonCancel,
                  kind: SheetButtonKind.secondary,
                  onTap: () => setState(() => _asksToStop = false),
                ),
                SheetButton(
                  key: SwapDetail.confirmStopKey,
                  label: l10n.swapStopTracking,
                  kind: SheetButtonKind.destructive,
                  onTap: () => _putAway(page.swap),
                ),
              ]),
            ],
          ),
        )
      else
        ToolbarActionRow(
          edge: ToolbarActionEdge.leading,
          wraps: true,
          children: [
            ?viewDeposit,
            ToolbarAction.symbol(
              symbol: CupertinoIcons.xmark_circle,
              label: l10n.swapStopTracking,
              onPressed: () => setState(() => _asksToStop = true),
            ),
          ],
        ),
      const SizedBox(height: 14),
      _attribution(page),
    ];
  }

  List<Widget> _deposit(_Page page) {
    final l10n = page.l10n;
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final swap = page.swap;
    final quote = swap.order.quote;
    final from = quote.fromToken;
    final address = swap.order.depositAddress;
    final memo = quote.depositMemo;
    final deadline = TimeOfDay.fromDateTime(quote.deadline.toLocal()).format(context);
    final mono = text.dataAddress.copyWith(height: 1.3, letterSpacing: 0.3, color: colors.textContent);
    Widget copied(String label, String value) => Row(
      children: [
        Expanded(child: CapsText(label, style: inspectorCapsStyle(context).copyWith(letterSpacing: 1.4))),
        CopyAction(text: value, copyLabel: l10n.receiveCopy, copiedLabel: l10n.desktopCopied),
      ],
    );

    return [
      inspectorStatusLine(
        context,
        mark: Icon(CupertinoIcons.clock, size: 13, color: colors.semanticSand),
        label: l10n.desktopSwapAwaitingDeposit,
        color: colors.semanticSand,
      ),
      const SizedBox(height: 14),
      inspectorHeadline(
        context,
        l10n.desktopSwapSendAmount(formatSwapAmount(l10n, page.fmt, quote.amountIn, from, exact: true)),
      ),
      const SizedBox(height: 10),
      Text(l10n.swapDepositOnly(from.symbol, from.networkName), style: text.body.copyWith(color: colors.semanticSand)),
      const SizedBox(height: 20),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox.square(
          dimension: 168,
          child: FittedBox(
            child: QuantusQr(
              accountId: address,
              logo: SwapTokenMark.network(token: from, size: 48),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      copied(l10n.swapDetailsDepositAddress, address),
      Text(address, style: mono),
      if (memo != null) ...[
        const SizedBox(height: 10),
        copied(l10n.swapDepositMemo, memo),
        Text(memo, style: mono),
        const SizedBox(height: 10),
        NoticeBox(
          tone: colors.semanticSand,
          symbol: CupertinoIcons.exclamationmark_triangle,
          child: Text(l10n.swapDepositMemoNotice, style: text.body.copyWith(color: colors.textContent)),
        ),
      ],
      const SizedBox(height: 12),
      NoticeBox(
        tone: colors.semanticSand,
        symbol: CupertinoIcons.clock,
        child: Text(l10n.swapDepositDeadline(deadline), style: text.body.copyWith(color: colors.textContent)),
      ),
      ..._pollError(page),
      const SizedBox(height: 16),
      // Before the terms: what the page is for stays in sight.
      _buttons([
        SheetButton(
          label: l10n.swapDepositSent,
          onTap: () => ref.read(activeSwapsProvider.notifier).markDepositSent(page.swap.id),
        ),
        SheetButton(label: l10n.desktopSwapCancel, kind: SheetButtonKind.secondary, onTap: () => _putAway(page.swap)),
      ]),
      const SizedBox(height: 16),
      const MenuDivider(),
      const SizedBox(height: 4),
      ...page.terms(),
      const SizedBox(height: 14),
      _attribution(page),
    ];
  }

  List<Widget> _complete(_Page page) {
    final l10n = page.l10n;
    final colors = context.colorsV3;
    final swap = page.swap;
    final quote = swap.order.quote;
    final viewDeposit = _viewDeposit(page);

    return [
      inspectorStatusLine(
        context,
        mark: Icon(CupertinoIcons.checkmark_alt, size: 13, color: colors.semanticSage),
        label: l10n.activityDetailStatusCompleted,
        color: colors.semanticSage,
        after: formatSwapElapsed(swap.elapsedAt(page.now)),
      ),
      const SizedBox(height: 14),
      inspectorHeadline(
        context,
        l10n.desktopSwapReceived(
          formatSwapAmount(l10n, page.fmt, swap.order.amountOut ?? quote.amountOut, quote.toToken),
        ),
      ),
      const SizedBox(height: 10),
      Text(l10n.desktopSwapCompleteBody(page.paid), style: context.themeTextV3.body.copyWith(color: colors.textMuted)),
      const SizedBox(height: 24),
      ...page.receiver(),
      const SizedBox(height: 20),
      const MenuDivider(),
      const SizedBox(height: 4),
      ...page.terms(),
      const SizedBox(height: 16),
      _buttons([SheetButton(label: l10n.commonDone, onTap: () => _putAway(page.swap)), ?viewDeposit], spacing: 14),
      const SizedBox(height: 14),
      _attribution(page),
    ];
  }

  List<Widget> _ended(_Page page, {required bool expired}) {
    final l10n = page.l10n;
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final swap = page.swap;
    final quote = swap.order.quote;
    final failure = swapFailureOf(
      l10n,
      page.fmt,
      swap,
      expired: expired,
      preflight: page.preflight,
      // Whole, as every address here is.
      addressLabel: (address) => address,
    );
    final isCaution = failure.isWarning || failure.refunded;
    final tone = isCaution ? colors.semanticSand : colors.semanticEmber;

    return [
      inspectorStatusLine(
        context,
        mark: Icon(
          isCaution ? CupertinoIcons.exclamationmark_triangle : CupertinoIcons.exclamationmark_circle,
          size: 13,
          color: tone,
        ),
        label: failure.refunded ? l10n.swapRefundedLabel : failure.title,
        color: tone,
      ),
      const SizedBox(height: 14),
      inspectorHeadline(context, page.paid),
      const SizedBox(height: 10),
      Text(page.forWhat, style: text.body.copyWith(color: colors.textMuted)),
      const SizedBox(height: 18),
      Text(failure.message, style: text.body.copyWith(color: colors.textContent)),
      ..._pollError(page),
      const SizedBox(height: 18),
      const MenuDivider(),
      const SizedBox(height: 4),
      if (expired)
        page.addressRow(l10n.swapDetailsDepositAddress, swap.order.depositAddress)
      else ...[
        FigureRow(label: l10n.swapYouPaid, value: page.paid),
        FigureRow(
          label: l10n.swapYouWereReceiving,
          value: formatSwapAmount(l10n, page.fmt, quote.amountOut, quote.toToken),
        ),
      ],
      const SizedBox(height: 16),
      _buttons([
        SheetButton(label: l10n.commonDone, onTap: () => _putAway(page.swap)),
        if (_canStartNew())
          SheetButton(
            key: SwapDetail.startNewKey,
            label: l10n.swapStartNew,
            kind: SheetButtonKind.secondary,
            onTap: () => unawaited(_startNew(page.swap)),
          ),
        ToolbarAction.symbol(
          symbol: CupertinoIcons.chat_bubble,
          label: l10n.commonContactSupport,
          onPressed: () => unawaited(ref.read(openExternalUrlProvider)(Uri.parse(AppConstants.discordSupportUrl))),
        ),
      ], spacing: 14),
      const SizedBox(height: 10),
      Text(l10n.commonSupportScamWarning, style: text.caption.copyWith(color: colors.textMuted)),
      const SizedBox(height: 14),
      _attribution(page),
    ];
  }
}

/// What the panel's pages say alike of the swap they show.
class _Page {
  const _Page({
    required this.context,
    required this.l10n,
    required this.fmt,
    required this.swap,
    required this.now,
    required this.preflight,
    required this.account,
  });

  final BuildContext context;
  final AppLocalizations l10n;
  final NumberFormattingService fmt;
  final ActiveSwap swap;
  final DateTime now;
  final bool preflight;

  /// The account the swap is from, while the wallet still has it.
  final BaseAccount? account;

  SwapQuote get _quote => swap.order.quote;

  /// Whether the swap pays out at an address outside the wallet: out of QTC,
  /// and in preflight always.
  bool get paysOutside => _quote.fromToken.isQuantus || preflight;

  /// What is paid, with its symbol.
  String get paid => formatSwapAmount(l10n, fmt, _quote.amountIn, _quote.fromToken);

  /// What it is paid for, and where that is.
  String get forWhat => l10n.desktopSwapForAmountOnNetwork(
    formatSwapAmount(l10n, fmt, _quote.amountOut, _quote.toToken),
    _quote.toToken.networkName,
  );

  TextStyle get _caps => inspectorCapsStyle(context).copyWith(letterSpacing: 1.4);

  TextStyle get _mono =>
      context.themeTextV3.dataAddress.copyWith(height: 1.3, letterSpacing: 0.3, color: context.colorsV3.textContent);

  /// The swap's account by its badge and name, or by the name it had when
  /// the wallet no longer holds it.
  Widget _account() {
    final account = this.account;
    return account == null
        ? Text(swap.accountName, style: context.themeTextV3.bodyEmphasis.copyWith(color: context.colorsV3.textContent))
        : AccountLabel(account: account, revealsAddress: true);
  }

  /// Who receives: the address on the other chain, whole, or the account.
  List<Widget> receiver() => [
    CapsText(
      paysOutside ? l10n.desktopSwapRecipientOn(_quote.toToken.networkName) : l10n.sendTxSubmittedToLabel,
      style: _caps,
    ),
    const SizedBox(height: 10),
    if (paysOutside) Text(_quote.recipient, style: _mono) else _account(),
  ];

  /// An address under its [label]: too long to share the line.
  Widget addressRow(String label, String address) => Padding(
    padding: SummaryRow.padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        inspectorLabel(context, label),
        const SizedBox(height: 6),
        Text(address, style: _mono),
      ],
    ),
  );

  /// The swap's terms: its rate and the least that arrives; what the app
  /// sent with its fee, or, for a deposit made by hand, who receives and
  /// where a refund goes.
  List<Widget> terms() {
    final from = _quote.fromToken;
    final to = _quote.toToken;
    final quantus = from.isQuantus ? from : to;
    final foreign = from.isQuantus ? to : from;
    final fee = swap.depositFee;
    return [
      if (!swap.depositByHand)
        SummaryRow(label: inspectorLabel(context, l10n.activityTxFrom), value: _account())
      else if (!paysOutside)
        SummaryRow(label: inspectorLabel(context, l10n.activityTxTo), value: _account()),
      FigureRow(
        label: l10n.swapRate,
        value: l10n.swapRateLabel(
          quantus.symbol,
          fmt.formatAmount(swapQuoteRate(_quote), decimals: foreign.decimals),
          foreign.symbol,
        ),
      ),
      FigureRow(label: l10n.swapReviewGuaranteedMinimum, value: formatSwapAmount(l10n, fmt, _quote.minAmountOut, to)),
      if (swap.depositByHand) addressRow(l10n.swapRefundTo, _quote.refundAddress),
      if (fee != null) ...[
        FigureRow(label: l10n.swapReviewNetworkFee, value: formatSwapAmount(l10n, fmt, fee, from)),
        const MenuDivider(),
        const SizedBox(height: 4),
        FigureRow(
          label: l10n.desktopSendYouPaid,
          value: formatSwapAmount(l10n, fmt, _quote.amountIn + fee, from),
          isStrong: true,
        ),
      ],
    ];
  }
}
