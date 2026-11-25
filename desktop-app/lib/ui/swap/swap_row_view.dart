import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/utils/swap_words.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/swap/swap_progress.dart';

/// A followed [swap], as a row of its account's In progress: open when it is
/// what the panel at the right shows, and a click opens it there.
class SwapEntry extends ConsumerWidget {
  const SwapEntry({super.key, required this.swap, required this.form, this.hasFocus = true});

  final ActiveSwap swap;
  final ActivityRowForm form;

  /// Whether the keys are in the panel the row is in.
  final bool hasFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opened = OpenedSwap(swap.id);
    return SwapRowView(
      swap: swap,
      form: form,
      isSelected: ref.watch(openedActivityViewProvider) == opened,
      hasFocus: hasFocus,
      onTap: () => ref.read(openedActivityProvider.notifier).open(opened),
    );
  }
}

/// One swap as a row of an activity list, in the [form] there is room for:
/// where it stands and for how long, what the account pays or receives, what
/// for on the other chain, and the step it is on. It stays, saying how it
/// ended, until the swap is put away.
///
/// Its backings are an activity row's: soft under the pointer, stronger when
/// it is open ([isSelected]), quieter while the keys are in another panel.
class SwapRowView extends ConsumerStatefulWidget {
  const SwapRowView({
    super.key,
    required this.swap,
    required this.form,
    this.isSelected = false,
    this.hasFocus = true,
    this.onTap,
  });

  final ActiveSwap swap;
  final ActivityRowForm form;
  final bool isSelected;
  final bool hasFocus;
  final VoidCallback? onTap;

  @override
  ConsumerState<SwapRowView> createState() => _SwapRowViewState();
}

class _SwapRowViewState extends ConsumerState<SwapRowView> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(SwapRowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) showWhenOpened(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final fmt = ref.watch(numberFormattingServiceProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    // Drawn again each second while the swap runs: its clock, and the moment
    // an awaited deposit's window closes.
    final now = ref.watch(swapClockProvider).value ?? clock.now();
    final swap = widget.swap;
    final swapOut = swap.order.quote.fromToken.isQuantus;
    final preflight = ref.watch(swapPreflightProvider) != null;
    final view = swapProgressViewOf(swap, now);
    final words = _wordsOf(context, l10n, fmt, swap, view, now, preflight: preflight);

    // The account's side of it: what it pays, or what it receives.
    final (:amount, :what) = swapAmountWords(l10n, fmt, swap);

    final ended = view == SwapProgressView.failed || view == SwapProgressView.expired;
    final muted = text.caption.copyWith(color: colors.textMuted, fontFeatures: const [FontFeature.tabularFigures()]);
    final icon = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: words.accent.useOpacity(0.08),
        borderRadius: context.radiusV3.xsBorder,
        border: Border.all(color: words.accent.useOpacity(0.15), width: 1.5),
      ),
      child: Center(child: QuantusIcon(QuantusIcons.actionSwap, size: 14, color: words.accent)),
    );
    final label = Text(
      words.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.bodyEmphasis.copyWith(color: words.accent),
    );
    final time = words.time == null ? null : Text(words.time!, maxLines: 1, style: muted);
    final amountText = Text(
      amount,
      style: text.amountRow.copyWith(
        // What arrives is in sage; what was paid is plain once it is done,
        // and what did not move is quiet.
        color: ended
            ? colors.textMuted
            : !swapOut
            ? colors.semanticSage
            : view == SwapProgressView.complete
            ? colors.textContent
            : words.accent,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final whatText = Text(
      what,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.body.copyWith(color: colors.textContent),
    );
    // The step it is on, with a part that moves while it runs, unless the
    // system asks for none.
    final step = words.step == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(words.step!, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
              ),
              if (view == SwapProgressView.inProgress && !MediaQuery.disableAnimationsOf(context)) ...[
                const SizedBox(width: 8),
                TerminalSpinner(style: text.dataAddress.copyWith(height: 1, color: colors.accentFlare)),
              ],
            ],
          );
    // What it is for takes the line; the step keeps to under half of it.
    Widget whatFor(TextStyle prefix, double prefixWidth) => LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          SizedBox(
            width: prefixWidth,
            child: Text(l10n.desktopSwapFor, style: prefix),
          ),
          Expanded(child: whatText),
          if (step != null) ...[
            const SizedBox(width: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
              child: step,
            ),
          ],
        ],
      ),
    );

    final backing = widget.isSelected
        ? colors.textContent.useOpacity(widget.hasFocus ? 0.1 : 0.05)
        : _isHovered
        ? colors.textContent.useOpacity(0.05)
        : null;
    final decoration = BoxDecoration(color: backing, borderRadius: context.radiusV3.smBorder);

    final Widget row = switch (widget.form) {
      ActivityRowForm.wide => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: decoration,
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            SizedBox(
              width: ActivityRowView.whatWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  if (time != null) ...[const SizedBox(height: 4), time],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: whatFor(text.body.copyWith(color: colors.textMuted), ActivityRowView.prefixWidth)),
            const SizedBox(width: 16),
            amountText,
          ],
        ),
      ),
      ActivityRowForm.tight => Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: decoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 28,
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: label),
                              if (time != null) ...[const SizedBox(width: 8), time],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        amountText,
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  whatFor(text.caption.copyWith(color: colors.textMuted), ActivityRowView.tightPrefixWidth),
                ],
              ),
            ),
          ],
        ),
      ),
      ActivityRowForm.brief => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: decoration,
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  if (time != null) ...[const SizedBox(height: 4), time],
                ],
              ),
            ),
            const SizedBox(width: 12),
            amountText,
          ],
        ),
      ),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: row),
    );
  }

  /// Where the swap stands in a word, since or until when, the step it is
  /// on, and the colour it is said in: glacier while it runs, sand while
  /// something is awaited or was a caution, sage once done, ember when it
  /// failed.
  ({String label, String? time, String? step, Color accent}) _wordsOf(
    BuildContext context,
    AppLocalizations l10n,
    NumberFormattingService fmt,
    ActiveSwap swap,
    SwapProgressView view,
    DateTime now, {
    required bool preflight,
  }) {
    final colors = context.colorsV3;
    final standing = swapStandingWords(l10n, fmt, swap, view, preflight: preflight);
    final time = switch (view) {
      SwapProgressView.inProgress || SwapProgressView.complete => formatSwapElapsed(swap.elapsedAt(now)),
      SwapProgressView.deposit => l10n.desktopSwapUntil(
        TimeOfDay.fromDateTime(swap.order.quote.deadline.toLocal()).format(context),
      ),
      SwapProgressView.failed || SwapProgressView.expired => null,
    };
    return (
      label: standing.label,
      time: time,
      step: standing.step,
      accent: switch (standing.tone) {
        SwapTone.running => colors.semanticGlacier,
        SwapTone.awaiting || SwapTone.caution => colors.semanticSand,
        SwapTone.done => colors.semanticSage,
        SwapTone.failed => colors.semanticEmber,
      },
    );
  }
}
