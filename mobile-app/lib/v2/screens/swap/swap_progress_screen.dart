import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/active_swap.dart';
import 'package:resonance_network_wallet/providers/active_swap_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/copy_icon_button.dart';
import 'package:resonance_network_wallet/v2/components/link_button.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_summary.dart';

/// Follows the active swap: the deposit address while a swap into QTC (or,
/// in preflight, any swap) waits for its deposit, then progress, and finally
/// the completed or failed swap. Leaving by Done, Dismiss, Cancel or Start
/// new puts the swap away, so the next tap on Swap starts a fresh one.
class SwapProgressScreen extends ConsumerStatefulWidget {
  /// The account a new swap would start from; none when the selected
  /// account cannot swap.
  final Account? account;

  const SwapProgressScreen({super.key, this.account});

  @override
  ConsumerState<SwapProgressScreen> createState() => _SwapProgressScreenState();
}

class _SwapProgressScreenState extends ConsumerState<SwapProgressScreen> {
  /// What was shown last: it stays on screen while the route leaves after
  /// the swap was put away.
  ActiveSwap? _shown;

  @override
  Widget build(BuildContext context) {
    final swap = _shown = ref.watch(activeSwapProvider) ?? _shown;
    if (swap == null) throw StateError('No active swap to show');
    ref.watch(swapElapsedProvider);
    final now = clock.now();
    final order = swap.order;
    final awaitingDeposit = order.status == SwapStatus.pendingDeposit && swap.depositByHand;
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
          child: LinkButton(label: l10n.commonRetry, onTap: () => ref.read(activeSwapProvider.notifier).refresh()),
        ),
      ],
    );
  }
}

/// Puts the swap away and returns home.
void _finish(BuildContext context, WidgetRef ref) {
  Navigator.popUntil(context, (route) => route.isFirst);
  ref.read(activeSwapProvider.notifier).clear();
}

/// Puts the swap away and opens the form for another.
void _startNew(BuildContext context, WidgetRef ref, Account account) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => SwapScreen(account: account)),
    (route) => route.isFirst,
  );
  ref.read(activeSwapProvider.notifier).clear();
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
    final receiver = quote.fromToken.isQuantus || ref.watch(swapPreflightProvider) != null
        ? AddressFormattingService.formatAddress(quote.recipient)
        : swap.accountName;
    final steps = swapStepLabels(l10n, quote, receiver);
    final stage = swapStage(order, depositByHand: swap.depositByHand);
    final pollError = swap.pollError;
    final deadlinePassed = swap.deadlinePassed(now);
    final stuck = deadlinePassed || swap.isStale(now);

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
            if (deadlinePassed) ...[
              const SizedBox(height: 16),
              QuantusBanner(tone: BannerTone.sand, message: l10n.swapProgressDepositNotSeen(swap.accountName)),
            ],
            if (swap.isStale(now)) ...[
              const SizedBox(height: 16),
              QuantusBanner(tone: BannerTone.sand, message: l10n.swapProgressDelayed),
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
            if (stuck) ...[
              const SizedBox(height: 24),
              QuantusButton.simple(
                label: l10n.swapDismiss,
                variant: ButtonVariant.staged,
                onTap: () => _finish(context, ref),
              ),
              const SizedBox(height: 4),
              QuantusButton.simple(
                label: l10n.swapContactSupport,
                variant: ButtonVariant.underline,
                onTap: () => openUrl(AppConstants.techSupportUrl),
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
    final quote = swap.order.quote;
    final fee = swap.depositFee;
    final tx = swap.depositTxHash ?? swap.order.originTxHashes.firstOrNull;

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
          const SizedBox(height: 32),
          QuantusButton.simple(
            label: l10n.commonDone,
            variant: ButtonVariant.staged,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
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

    return ScaffoldBase(
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
            Text(to.networkName, style: text.body.copyWith(color: colors.accentFlare)),
            const SizedBox(height: 4),
            Text(
              AddressFormattingService.formatAddress(quote.recipient),
              style: text.dataAddress.copyWith(color: colors.textContent),
            ),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: l10n.commonDone, onTap: () => _finish(context, ref)),
      ),
    );
  }
}

/// A swap that ended without paying out: refunded, failed, short-paid, or a
/// deposit window that closed with nothing sent.
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

    return ScaffoldBase(
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
              onTap: starter == null ? null : () => _startNew(context, ref, starter),
            ),
            const SizedBox(height: 4),
            QuantusButton.simple(
              label: l10n.commonDone,
              variant: ButtonVariant.staged,
              onTap: () => _finish(context, ref),
            ),
            const SizedBox(height: 4),
            QuantusButton.simple(
              label: l10n.swapContactSupport,
              variant: ButtonVariant.underline,
              onTap: () => openUrl(AppConstants.techSupportUrl),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where to send the external token for a swap into QTC, or the stand-in for
/// a swap out of it in preflight.
class _SwapDeposit extends ConsumerWidget {
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
    Future<void> copyAddress() => context.copyTextWithToaster(address, message: l10n.swapDepositAddressCopied);
    final shareContent = memo == null
        ? l10n.swapDepositShareContent(from.networkName, from.symbol, address)
        : l10n.swapDepositShareContentMemo(from.networkName, from.symbol, address, memo);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.swapTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            SwapDetailRow(label: l10n.swapDepositToken, value: from.symbol),
            SwapDetailRow(label: l10n.swapDepositNetwork, value: from.networkName),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.swapDepositAmount, style: text.body.copyWith(color: colors.textContent)),
                const SizedBox(width: 6),
                CopyIconButton(
                  text: fmt.formatWireAmount(quote.amountIn, decimals: from.decimals),
                  copiedMessage: l10n.swapDepositAmountCopied,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TokenIcon(token: from, size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      fmt.formatExactAmount(quote.amountIn, decimals: from.decimals),
                      style: text.amountHero.copyWith(color: colors.textContent),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('\$${quote.amountInUsd.toStringAsFixed(2)}', style: text.body.copyWith(color: colors.textMuted)),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: context.radiusV3.smBorder,
              child: Container(
                color: colors.textWhite,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: address, version: QrVersions.auto, size: 184),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: copyAddress,
              child: Text(
                address,
                style: text.dataAddress.copyWith(color: colors.textContent),
                textAlign: TextAlign.center,
              ),
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Loader(color: colors.semanticSage, size: 14),
                const SizedBox(width: 8),
                Text(l10n.swapDepositWaiting, style: text.caption.copyWith(color: colors.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.swapDepositDeadline(deadline),
              style: text.bodyEmphasis.copyWith(color: colors.accentFlare),
              textAlign: TextAlign.center,
            ),
            if (swap.pollError case final error?) ...[const SizedBox(height: 16), _PollErrorNotice(error: error)],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: QuantusButton.simple(
                    label: l10n.receiveCopy,
                    variant: ButtonVariant.staged,
                    onTap: copyAddress,
                    icon: Icon(Icons.copy, color: colors.textContent, size: 20),
                    iconPlacement: IconPlacement.leading,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: QuantusButton.simple(
                    label: l10n.swapDepositShareQr,
                    icon: Icon(Icons.qr_code, color: colors.textContent, size: 20),
                    iconPlacement: IconPlacement.leading,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    variant: ButtonVariant.staged,
                    onTap: () => shareText(context, shareContent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              l10n.swapDepositNotice(from.symbol, from.networkName),
              style: text.caption.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            QuantusButton.simple(
              label: l10n.swapDepositCancel,
              variant: ButtonVariant.underline,
              onTap: () => _finish(context, ref),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
