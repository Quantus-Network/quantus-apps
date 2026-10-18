import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/active_swaps_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/v2/components/copy_icon_button.dart';
import 'package:resonance_network_wallet/v2/components/link_button.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/settings/help_and_support_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_summary.dart';

/// Follows the active swap: the deposit address while a swap into QTC (or,
/// in preflight, any swap) waits for its deposit, then progress, and finally
/// the completed or failed swap. Leaving a settled swap by Done, Start new
/// or going back puts it away, as does leaving the deposit screen before the
/// deposit is sent; a running swap left by going back is still followed. Its
/// details sheet, or the notice once it is overdue, offers to stop tracking.
class SwapProgressScreen extends ConsumerStatefulWidget {
  /// The followed swap to show, by [ActiveSwap.id].
  final String swapId;

  /// The account a new swap would start from; none when the selected
  /// account cannot swap.
  final Account? account;

  const SwapProgressScreen({super.key, required this.swapId, this.account});

  @override
  ConsumerState<SwapProgressScreen> createState() => _SwapProgressScreenState();
}

class _SwapProgressScreenState extends ConsumerState<SwapProgressScreen> {
  /// What was shown last: it stays on screen while the route leaves after
  /// the swap was put away.
  ActiveSwap? _shown;

  @override
  Widget build(BuildContext context) {
    final swap = _shown = ref.watch(activeSwapProvider(widget.swapId)) ?? _shown;
    if (swap == null) throw StateError('No followed swap ${widget.swapId} to show');
    final now = ref.watch(swapClockProvider).value ?? clock.now();
    final order = swap.order;
    final awaitingDeposit = order.status == SwapStatus.pendingDeposit && !swap.depositUnderway;
    final expired = awaitingDeposit && now.isAfter(order.quote.deadline);
    return switch (order.status) {
      SwapStatus.success => _SwapComplete(swap: swap),
      SwapStatus.refunded ||
      SwapStatus.failed ||
      SwapStatus.incompleteDeposit => _SwapFailed(swap: swap, account: widget.account),
      _ when expired => _SwapFailed(swap: swap, account: widget.account, expired: true),
      _ when awaitingDeposit => _SwapDeposit(swap: swap),
      _ => _SwapInProgress(swap: swap, now: now),
    };
  }
}

/// Why the status cannot be checked, with a retry; shown on every screen of
/// a swap that is still being polled.
class _PollErrorNotice extends ConsumerWidget {
  final String error;

  const _PollErrorNotice({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuantusBanner(tone: BannerTone.sand, message: l10n.swapProgressStatusUnavailable(error)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: LinkButton(label: l10n.commonRetry, onTap: () => ref.read(activeSwapsProvider.notifier).refresh()),
        ),
      ],
    );
  }
}

/// Puts the swap away and returns home.
void _finish(BuildContext context, WidgetRef ref, String id) {
  Navigator.popUntil(context, (route) => route.isFirst);
  ref.read(activeSwapsProvider.notifier).remove(id);
}

/// Puts the swap away and opens the form for another.
void _startNew(BuildContext context, WidgetRef ref, Account account, String id) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => SwapScreen(account: account)),
    (route) => route.isFirst,
  );
  ref.read(activeSwapsProvider.notifier).remove(id);
}

class _SwapInProgress extends ConsumerWidget {
  static const _listAsset = 'assets/v2/swap_list.svg';

  final ActiveSwap swap;
  final DateTime now;

  const _SwapInProgress({required this.swap, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final order = swap.order;
    final quote = order.quote;
    final receiver = swapReceiver(swap, preflight: ref.watch(swapPreflightProvider) != null);
    final refund = swap.depositByHand ? AddressFormattingService.formatAddress(quote.refundAddress) : swap.accountName;
    final steps = swapStepLabels(l10n, quote, receiver, byHand: swap.depositByHand);
    final stage = swapStage(order, depositByHand: swap.depositByHand);
    final pollError = swap.pollError;
    final overdue = swap.overdue(now);

    return ScaffoldBase(
      appBar: V2AppBar(
        title: l10n.swapInProgressTitle,
        trailing: GestureDetector(
          onTap: () => BottomSheetContainer.show(context, builder: (_) => _SwapDetailsSheet(swap: swap)),
          child: SvgPicture.asset(
            _listAsset,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(colors.textContent, BlendMode.srcIn),
          ),
        ),
      ),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            SwapAmountsCard(quote: quote, payLabel: l10n.swapYourePaying, receiveLabel: l10n.swapYoureReceiving),
            const SizedBox(height: 36),
            for (final (i, label) in steps.indexed)
              QuantusStepRow(
                state: i < stage
                    ? StepRowState.done
                    : i == stage
                    ? StepRowState.active
                    : StepRowState.pending,
                label: label,
              ),
            if (pollError != null) ...[const SizedBox(height: 16), _PollErrorNotice(error: pollError)],
            if (overdue) ...[
              const SizedBox(height: 16),
              QuantusBanner(tone: BannerTone.sand, message: l10n.swapProgressOverdue(refund)),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: (stage + 0.5) / steps.length,
              minHeight: 4,
              backgroundColor: colors.bgSurface2,
              color: colors.accentFlare,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.swapProgressFooter,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: colors.textMuted2),
            ),
            if (overdue) ...[
              const SizedBox(height: 8),
              QuantusButton.simple(
                label: l10n.swapStopTracking,
                variant: ButtonVariant.underline,
                onTap: () => _finish(context, ref, swap.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwapDetailsSheet extends ConsumerWidget {
  final ActiveSwap swap;

  const _SwapDetailsSheet({required this.swap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final fmt = ref.watch(numberFormattingServiceProvider);
    final order = swap.order;
    final quote = order.quote;
    final fee = swap.depositFee;
    final tx = swap.depositTxHash ?? order.originTxHashes.firstOrNull;

    return BottomSheetContainer(
      title: l10n.swapDetailsTitle,
      trailing: QuantusIconButton.ghost(
        icon: Icons.close,
        onTap: () => Navigator.pop(context),
        size: IconButtonSize.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (swap.depositByHand) ...[
            SwapDetailRow(
              label: l10n.swapDetailsDepositAddress,
              value: AddressFormattingService.formatAddress(order.depositAddress),
              monoValue: true,
            ),
            SwapDetailRow(
              label: l10n.swapDetailsRequiredDeposit,
              value: formatSwapAmount(l10n, fmt, quote.amountIn, quote.fromToken, exact: true),
            ),
            SwapDetailRow(
              label: l10n.swapDetailsDepositWindowEnds,
              value: TimeOfDay.fromDateTime(quote.deadline.toLocal()).format(context),
            ),
          ] else ...[
            SwapDetailRow(
              label: l10n.swapDetailsRecipient,
              value: AddressFormattingService.formatAddress(quote.recipient),
              monoValue: true,
            ),
            SwapDetailRow(
              label: l10n.swapDetailsAmountSent,
              value: formatSwapAmount(l10n, fmt, quote.amountIn, quote.fromToken, exact: true),
            ),
            if (fee != null)
              SwapDetailRow(label: l10n.swapReviewNetworkFee, value: formatSwapAmount(l10n, fmt, fee, quote.fromToken)),
            SwapDetailRow(
              label: l10n.swapDetailsExpected,
              value: formatSwapAmount(l10n, fmt, quote.amountOut, quote.toToken),
            ),
            if (tx != null) ...[
              const MenuDivider(),
              SwapDetailRow(
                label: l10n.swapDetailsTransaction,
                value: AddressFormattingService.formatAddress(tx),
                monoValue: true,
              ),
            ],
          ],
          const SizedBox(height: 32),
          QuantusButton.simple(
            label: l10n.commonDone,
            variant: ButtonVariant.staged,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 4),
          QuantusButton.simple(
            label: l10n.swapStopTracking,
            variant: ButtonVariant.underline,
            onTap: () => _stopTracking(context, ref, l10n, swap.id),
          ),
        ],
      ),
    );
  }
}

/// Puts the swap away once the user confirms; it carries on at 1Click.
Future<void> _stopTracking(BuildContext context, WidgetRef ref, AppLocalizations l10n, String id) async {
  final confirmed = await showConfirmActionSheet(
    context,
    title: l10n.swapStopTrackingConfirmTitle,
    message: l10n.swapStopTrackingConfirmBody,
    confirmLabel: l10n.swapStopTracking,
    cancelLabel: l10n.commonCancel,
  );
  if (confirmed && context.mounted) _finish(context, ref, id);
}

class _SwapComplete extends ConsumerWidget {
  final ActiveSwap swap;

  const _SwapComplete({required this.swap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final order = swap.order;
    final quote = order.quote;
    final to = quote.toToken;
    final receiver = to.isQuantus && ref.watch(swapPreflightProvider) == null ? swap.accountName : to.networkName;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(activeSwapsProvider.notifier).remove(swap.id);
      },
      child: ScaffoldBase(
        appBar: V2AppBar(title: l10n.swapCompleteTitle),
        mainContent: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SuccessCheck(size: 80),
              const SizedBox(height: 40),
              Text(
                formatSwapAmount(l10n, fmt, order.amountOut ?? quote.amountOut, to),
                style: text.titleSuccess.copyWith(color: colors.textContent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(l10n.swapCompleteReceived, style: text.caption.copyWith(color: colors.textMuted)),
              const SizedBox(height: 48),
              Text(l10n.swapCompleteTo, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
              const SizedBox(height: 16),
              Text(receiver, style: text.body.copyWith(color: colors.accentFlare)),
              const SizedBox(height: 4),
              Text(
                AddressFormattingService.formatAddress(quote.recipient),
                style: text.dataAddress.copyWith(color: colors.textContent),
              ),
            ],
          ),
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: QuantusButton.simple(label: l10n.commonDone, onTap: () => _finish(context, ref, swap.id)),
        ),
      ),
    );
  }
}

/// A swap that ended without paying out: refunded, failed, short-paid, or a
/// deposit window that closed with nothing sent. Going back puts it away;
/// Contact Support opens Help & Support.
class _SwapFailed extends ConsumerWidget {
  final ActiveSwap swap;
  final Account? account;
  final bool expired;

  const _SwapFailed({required this.swap, this.account, this.expired = false});

  String _message(AppLocalizations l10n, NumberFormattingService fmt, {required bool preflight}) {
    final order = swap.order;
    final quote = order.quote;
    final from = quote.fromToken;
    if (expired) return l10n.swapDepositExpiredBody;
    return switch (order.status) {
      SwapStatus.refunded => [
        l10n.swapRefundedBody(
          formatSwapAmount(l10n, fmt, order.refundedAmount ?? quote.amountIn, from),
          from.isQuantus && !preflight ? swap.accountName : AddressFormattingService.formatAddress(quote.refundAddress),
          quote.toToken.symbol,
        ),
        if (order.refundReason != null) l10n.swapDepositRefundReason(order.refundReason!),
      ].join('\n\n'),
      SwapStatus.incompleteDeposit => l10n.swapDepositIncompleteBody,
      _ => l10n.swapDepositFailedBody(order.depositAddress),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final order = swap.order;
    final refunded = order.status == SwapStatus.refunded;
    final warning = expired || order.status == SwapStatus.incompleteDeposit;
    final pollError = swap.isFinal ? null : swap.pollError;
    final starter = account;
    final swapsOffered = ref.watch(remoteConfigProvider.select((c) => c.swapAvailable));

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(activeSwapsProvider.notifier).remove(swap.id);
      },
      child: ScaffoldBase(
        appBar: V2AppBar(
          title: expired
              ? l10n.swapDepositExpiredTitle
              : order.status == SwapStatus.incompleteDeposit
              ? l10n.swapDepositIncompleteTitle
              : l10n.swapFailedTitle,
        ),
        mainContent: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              if (refunded) ...[
                Text(
                  l10n.swapRefundedLabel.toUpperCase(),
                  style: text.labelMonogram.copyWith(color: colors.semanticSand),
                ),
                const SizedBox(height: 12),
              ],
              if (!expired) ...[
                SwapAmountsCard(
                  quote: order.quote,
                  payLabel: l10n.swapYouPaid,
                  receiveLabel: l10n.swapYouWereReceiving,
                  amountOut: order.amountOut,
                  receiveDimmed: true,
                ),
                const SizedBox(height: 32),
              ],
              QuantusBanner(
                tone: warning ? BannerTone.sand : BannerTone.ember,
                message: _message(l10n, fmt, preflight: ref.watch(swapPreflightProvider) != null),
              ),
              if (pollError != null) ...[const SizedBox(height: 16), _PollErrorNotice(error: pollError)],
            ],
          ),
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuantusButton.simple(
                label: l10n.swapStartNew,
                isDisabled: starter == null || !starter.signsLocally || !swapsOffered,
                onTap: starter == null ? null : () => _startNew(context, ref, starter, swap.id),
              ),
              const SizedBox(height: 4),
              QuantusButton.simple(
                label: l10n.commonContactSupport,
                variant: ButtonVariant.underline,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpAndSupportScreenV2())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where to send the external token for a swap into QTC, or the stand-in for
/// a swap out of it in preflight. "I've sent it" moves the swap on to its
/// progress, where 1Click's own sighting of the deposit is awaited.
class _SwapDeposit extends ConsumerWidget {
  static const _addressWidth = 186.0;
  static const _networkLogoSize = 48.0;

  final ActiveSwap swap;

  const _SwapDeposit({required this.swap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final order = swap.order;
    final quote = order.quote;
    final from = quote.fromToken;
    final address = order.depositAddress;
    final memo = quote.depositMemo;
    final deadline = TimeOfDay.fromDateTime(quote.deadline.toLocal()).format(context);
    final corner = Radius.circular(context.radiusV3.md);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(activeSwapsProvider.notifier).remove(swap.id);
      },
      child: ScaffoldBase(
        appBar: V2AppBar(title: l10n.swapDepositTitle),
        mainContent: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              QuantusQr(
                accountId: address,
                borderRadius: BorderRadius.vertical(top: corner),
                logo: TokenIcon.network(token: from, size: _networkLogoSize),
              ),
              Container(
                width: QuantusQr.size,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  border: Border.all(color: colors.borderHairline),
                  borderRadius: BorderRadius.vertical(bottom: corner),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TokenIcon(token: from, size: 28),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatSwapAmount(l10n, fmt, quote.amountIn, from, exact: true),
                          style: text.amountHero.copyWith(color: colors.textContent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text.rich(
                _emphasised(
                  l10n.swapDepositOnly(from.symbol, from.networkName),
                  [from.symbol, from.networkName],
                  style: text.body.copyWith(color: colors.semanticSand),
                  emphasis: text.bodyEmphasis.copyWith(color: colors.textContent),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                l10n.swapDetailsDepositAddress.toUpperCase(),
                style: text.labelMonogram.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _addressWidth,
                    child: Text(
                      address,
                      textAlign: TextAlign.center,
                      style: text.bodyEmphasis.copyWith(color: colors.textContent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CopyIconButton(text: address, copiedMessage: l10n.swapDepositAddressCopied, size: 32, round: true),
                ],
              ),
              if (memo != null) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => context.copyTextWithToaster(memo, message: l10n.swapDepositMemoCopied),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Text(
                        l10n.swapDepositMemo.toUpperCase(),
                        style: text.labelMonogram.copyWith(color: colors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        memo,
                        style: text.dataAddressLarge.copyWith(color: colors.textContent),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                QuantusBanner(tone: BannerTone.sand, message: l10n.swapDepositMemoNotice),
              ],
              if (swap.pollError case final error?) ...[const SizedBox(height: 16), _PollErrorNotice(error: error)],
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.swapDepositDeadline(deadline),
                textAlign: TextAlign.center,
                style: text.caption.copyWith(color: colors.accentFlare),
              ),
              const SizedBox(height: 16),
              QuantusButton.simple(
                label: l10n.swapDepositSent,
                onTap: () => ref.read(activeSwapsProvider.notifier).markDepositSent(swap.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [sentence] in [style], with each of [words] where it occurs in [emphasis].
TextSpan _emphasised(String sentence, List<String> words, {required TextStyle style, required TextStyle emphasis}) {
  final spans = <TextSpan>[];
  var rest = sentence;
  while (rest.isNotEmpty) {
    var at = rest.length;
    String? word;
    for (final candidate in words.where((w) => w.isNotEmpty)) {
      final index = rest.indexOf(candidate);
      if (index >= 0 && index < at) {
        at = index;
        word = candidate;
      }
    }
    if (word == null) {
      spans.add(TextSpan(text: rest));
      break;
    }
    if (at > 0) spans.add(TextSpan(text: rest.substring(0, at)));
    spans.add(TextSpan(text: word, style: emphasis));
    rest = rest.substring(at + word.length);
  }
  return TextSpan(style: style, children: spans);
}
