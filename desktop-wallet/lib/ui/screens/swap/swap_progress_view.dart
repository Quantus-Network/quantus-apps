import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/copyable_text.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_card.dart';
import 'package:quantus_desktop_wallet/ui/components/explorer_link.dart';
import 'package:quantus_desktop_wallet/ui/components/success_mark.dart';
import 'package:quantus_desktop_wallet/ui/screens/swap/swap_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// Follows [order] after its deposit was broadcast until it settles.
class SwapProgressView extends ConsumerWidget {
  final SwapOrder order;
  final String depositHash;
  final BigInt? depositFee;
  final VoidCallback onStartNew;

  const SwapProgressView({
    super.key,
    required this.order,
    required this.depositHash,
    required this.depositFee,
    required this.onStartNew,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final current = ref.watch(swapOrderProvider(order)).value ?? order;
    final expired = current.status == SwapStatus.pendingDeposit && current.quote.deadline.isBefore(DateTime.now());
    final body = switch (current.status) {
      SwapStatus.success => _Complete(order: current),
      SwapStatus.refunded || SwapStatus.failed || SwapStatus.incompleteDeposit => _Failed(order: current),
      _ when expired => _Failed(order: current, expired: true),
      _ => _InProgress(order: current),
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: DesktopCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            body,
            const SizedBox(height: 20),
            QuantusDataRow(
              label: l10n.swapDepositTransaction,
              value: AddressFormattingService.formatAddress(depositHash),
              trailing: ExplorerLink(extrinsicHash: depositHash, label: l10n.accountOpenExplorer),
            ),
            if (depositFee != null)
              QuantusDataRow(
                label: l10n.swapNetworkFee,
                value: formatSwapAmount(
                  ref.watch(numberFormattingServiceProvider),
                  depositFee!,
                  current.quote.fromToken,
                  exact: true,
                ),
              ),
            const SizedBox(height: 20),
            QuantusButton.simple(label: l10n.swapStartNew, variant: ButtonVariant.staged, onTap: onStartNew),
          ],
        ),
      ),
    );
  }
}

class _InProgress extends ConsumerWidget {
  final SwapOrder order;

  const _InProgress({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final quote = order.quote;
    final steps = [
      l10n.swapStepSent,
      l10n.swapStepConfirming,
      l10n.swapStepSwapping,
      l10n.swapStepSending(quote.toToken.symbol, AddressFormattingService.formatAddress(quote.recipient)),
    ];
    final stage = order.status == SwapStatus.processing ? 2 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.swapInProgress, style: text.titleScreen.copyWith(color: colors.textContent)),
        const SizedBox(height: 16),
        SwapAmountsCard(quote: quote, payLabel: l10n.swapPayLabel, receiveLabel: l10n.swapReceiveLabel),
        const SizedBox(height: 16),
        for (final (i, step) in steps.indexed)
          QuantusStepRow(
            state: i < stage
                ? StepRowState.done
                : i == stage
                ? StepRowState.active
                : StepRowState.pending,
            label: step,
          ),
        const SizedBox(height: 12),
        Text(l10n.swapProgressFooter, style: text.caption.copyWith(color: colors.textMuted)),
      ],
    );
  }
}

class _Complete extends ConsumerWidget {
  final SwapOrder order;

  const _Complete({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatter = ref.watch(numberFormattingServiceProvider);
    final quote = order.quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: SuccessMark()),
        const SizedBox(height: 16),
        Text(
          l10n.swapComplete,
          style: text.titleSuccess.copyWith(color: colors.textContent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        QuantusDataRow(
          label: l10n.swapReceived,
          value: formatSwapAmount(formatter, order.amountOut ?? quote.amountOut, quote.toToken, exact: true),
        ),
        QuantusDataRow(label: l10n.swapRecipient, value: AddressFormattingService.formatAddress(quote.recipient)),
        for (final hash in order.destinationTxHashes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: CopyableText(value: hash, copiedMessage: l10n.commonCopied),
          ),
      ],
    );
  }
}

class _Failed extends ConsumerWidget {
  final SwapOrder order;
  final bool expired;

  const _Failed({required this.order, this.expired = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatter = ref.watch(numberFormattingServiceProvider);
    final account = ref.watch(currentAccountProvider);
    final quote = order.quote;
    final (String title, String body) = switch (order.status) {
      _ when expired => (l10n.swapExpiredTitle, l10n.swapExpiredBody),
      SwapStatus.refunded => (
        l10n.swapRefunded,
        [
          l10n.swapRefundedBody(
            formatSwapAmount(formatter, order.refundedAmount ?? quote.amountIn, quote.fromToken, exact: true),
            account?.name ?? AddressFormattingService.formatAddress(quote.refundAddress),
            quote.toToken.symbol,
          ),
          if (order.refundReason != null) l10n.swapRefundReason(order.refundReason!),
        ].join(' '),
      ),
      SwapStatus.incompleteDeposit => (l10n.swapDepositIncompleteTitle, l10n.swapDepositIncompleteBody),
      _ => (l10n.swapFailed, l10n.swapFailedBody(order.depositAddress)),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: text.titleScreen.copyWith(color: colors.textContent)),
        const SizedBox(height: 12),
        QuantusBanner(
          tone: expired || order.status == SwapStatus.incompleteDeposit ? BannerTone.sand : BannerTone.ember,
          message: body,
        ),
        const SizedBox(height: 16),
        SwapAmountsCard(quote: quote, payLabel: l10n.swapPayLabel, receiveLabel: l10n.swapReceiveLabel),
      ],
    );
  }
}
