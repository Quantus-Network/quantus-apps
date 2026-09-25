import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_summary.dart';

/// Follows a live swap through 1Click's status endpoint: the deposit address
/// while a swap into QTC waits for its deposit, then progress, and finally
/// the completed or failed swap.
class SwapProgressScreen extends ConsumerWidget {
  final Account account;
  final SwapOrder order;

  /// Hash and fee of the QTC transfer that paid a swap out of QTC.
  final String? depositTxHash;
  final BigInt? depositFee;

  const SwapProgressScreen({
    super.key,
    required this.account,
    required this.order,
    this.depositTxHash,
    this.depositFee,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(swapOrderProvider(order)).value ?? order;
    final awaitingDeposit = current.status == SwapStatus.pendingDeposit && !current.quote.fromToken.isQuantus;
    final expired = awaitingDeposit && DateTime.now().isAfter(current.quote.deadline);
    return switch (current.status) {
      SwapStatus.success => _SwapComplete(order: current),
      SwapStatus.refunded ||
      SwapStatus.failed ||
      SwapStatus.incompleteDeposit => _SwapFailed(order: current, account: account),
      _ when expired => _SwapFailed(order: current, account: account, expired: true),
      _ when awaitingDeposit => _SwapDeposit(order: current),
      _ => _SwapInProgress(order: current, account: account, depositTxHash: depositTxHash, depositFee: depositFee),
    };
  }
}

class _SwapInProgress extends ConsumerWidget {
  static const _listAsset = 'assets/v2/swap_list.svg';

  final SwapOrder order;
  final Account account;
  final String? depositTxHash;
  final BigInt? depositFee;

  const _SwapInProgress({required this.order, required this.account, this.depositTxHash, this.depositFee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final quote = order.quote;
    final from = quote.fromToken;
    final to = quote.toToken;
    final receiver = from.isQuantus ? AddressFormattingService.formatAddress(quote.recipient) : account.name;
    final steps = [
      l10n.swapStepSent(from.symbol),
      l10n.swapStepConfirming(from.networkName),
      l10n.swapStepSwapping,
      l10n.swapStepSending(to.symbol, receiver),
    ];
    final stage = order.status == SwapStatus.processing ? 2 : 1;

    return ScaffoldBase(
      appBar: V2AppBar(
        title: l10n.swapInProgressTitle,
        trailing: GestureDetector(
          onTap: () => BottomSheetContainer.show(
            context,
            builder: (_) => _SwapDetailsSheet(order: order, depositTxHash: depositTxHash, depositFee: depositFee),
          ),
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
          ],
        ),
      ),
    );
  }
}

class _SwapDetailsSheet extends ConsumerWidget {
  final SwapOrder order;
  final String? depositTxHash;
  final BigInt? depositFee;

  const _SwapDetailsSheet({required this.order, this.depositTxHash, this.depositFee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final fmt = ref.watch(numberFormattingServiceProvider);
    final quote = order.quote;
    final fee = depositFee;
    final tx = depositTxHash ?? order.originTxHashes.firstOrNull;

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
            value: formatSwapAmount(l10n, fmt, quote.amountIn, quote.fromToken),
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
  final SwapOrder order;

  const _SwapComplete({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
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
        child: QuantusButton.simple(
          label: l10n.commonDone,
          onTap: () => Navigator.popUntil(context, (route) => route.isFirst),
        ),
      ),
    );
  }
}

/// A swap that ended without paying out: refunded, failed, short-paid, or a
/// deposit window that closed with nothing sent.
class _SwapFailed extends ConsumerWidget {
  final SwapOrder order;
  final Account account;
  final bool expired;

  const _SwapFailed({required this.order, required this.account, this.expired = false});

  String _message(AppLocalizations l10n, NumberFormattingService fmt) {
    final quote = order.quote;
    final from = quote.fromToken;
    if (expired) return l10n.swapDepositExpiredBody;
    return switch (order.status) {
      SwapStatus.refunded => [
        l10n.swapRefundedBody(
          formatSwapAmount(l10n, fmt, order.refundedAmount ?? quote.amountIn, from),
          from.isQuantus ? account.name : AddressFormattingService.formatAddress(quote.refundAddress),
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
    final refunded = order.status == SwapStatus.refunded;
    final warning = expired || order.status == SwapStatus.incompleteDeposit;

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
            QuantusBanner(tone: warning ? BannerTone.sand : BannerTone.ember, message: _message(l10n, fmt)),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuantusButton.simple(
              label: l10n.swapStartNew,
              onTap: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => SwapScreen(account: account)),
                (route) => route.isFirst,
              ),
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

/// Where to send the external token for a swap into QTC.
class _SwapDeposit extends ConsumerWidget {
  final SwapOrder order;

  const _SwapDeposit({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final quote = order.quote;
    final from = quote.fromToken;
    final address = order.depositAddress;
    final deadline = TimeOfDay.fromDateTime(quote.deadline.toLocal()).format(context);
    Future<void> copyAddress() => context.copyTextWithToaster(address, message: l10n.swapDepositAddressCopied);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.swapTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(l10n.swapDepositAmount, style: text.body.copyWith(color: colors.textContent)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => context.copyTextWithToaster(
                    fmt.formatWireAmount(quote.amountIn, decimals: from.decimals),
                    message: l10n.swapDepositAmountCopied,
                  ),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.xsBorder),
                    child: Center(child: Icon(Icons.copy, color: colors.textContent, size: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TokenIcon(token: from, size: 28, networkBadgeSize: 11),
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
                    onTap: () =>
                        shareText(context, l10n.swapDepositShareContent(from.networkName, from.symbol, address)),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
