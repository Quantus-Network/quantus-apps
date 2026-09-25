import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// Shows where to send the origin-chain funds and follows the swap from
/// 1Click's status endpoint until it settles, refunds, or fails.
class DepositScreen extends ConsumerStatefulWidget {
  final SwapOrder order;
  const DepositScreen({super.key, required this.order});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  late SwapOrder _order;
  Timer? _timer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _timer = Timer.periodic(SwapService.statusPollInterval, (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final updated = await ref.read(swapServiceProvider).getSwapStatus(_order);
      if (!mounted) return;
      setState(() => _order = updated);
      if (updated.status.isFinal) _timer?.cancel();
    } catch (e) {
      quantusPrint('Swap status poll failed: $e');
    } finally {
      _polling = false;
    }
  }

  bool get _expired => _order.status == SwapStatus.pendingDeposit && DateTime.now().isAfter(_order.quote.deadline);

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final quote = _order.quote;
    final from = quote.fromToken;

    final body = switch (_order.status) {
      SwapStatus.pendingDeposit when _expired => _outcome(
        colors,
        text,
        icon: Icon(Icons.timer_off_outlined, color: colors.textMuted, size: 64),
        title: l10n.swapDepositExpiredTitle,
        body: l10n.swapDepositExpiredBody,
      ),
      SwapStatus.pendingDeposit => _depositBody(l10n, colors, text, fmt),
      SwapStatus.knownDepositTx => _processingBody(l10n, colors, text, l10n.swapDepositDetectedBody(from.network)),
      SwapStatus.processing => _processingBody(l10n, colors, text, l10n.swapDepositProcessingBody),
      SwapStatus.incompleteDeposit => _outcome(
        colors,
        text,
        icon: Icon(Icons.warning_amber_rounded, color: colors.semanticSand, size: 64),
        title: l10n.swapDepositIncompleteTitle,
        body: l10n.swapDepositIncompleteBody,
      ),
      SwapStatus.success => _completedBody(l10n, colors, text, fmt),
      SwapStatus.refunded => _outcome(
        colors,
        text,
        icon: Icon(Icons.undo, color: colors.semanticSand, size: 64),
        title: l10n.swapDepositRefundedTitle,
        body: _refundedText(l10n, fmt),
      ),
      SwapStatus.failed => _outcome(
        colors,
        text,
        icon: Icon(Icons.error_outline, color: colors.semanticEmber, size: 64),
        title: l10n.swapDepositFailedTitle,
        body: l10n.swapDepositFailedBody(_order.depositAddress),
      ),
    };

    return ScaffoldBase(
      appBar: V2AppBar(
        title: l10n.swapTitle,
        trailing: Icon(Icons.info_outline, color: colors.textContent, size: 24),
      ),
      mainContent: Column(
        children: [
          Expanded(child: SingleChildScrollView(child: body)),
          if (_order.status.isFinal || _expired) ...[const SizedBox(height: 16), _doneButton(l10n)],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _refundedText(AppLocalizations l10n, NumberFormattingService fmt) {
    final from = _order.quote.fromToken;
    final amount = fmt.formatAmount(_order.refundedAmount ?? _order.quote.amountIn, decimals: from.decimals);
    final reason = _order.refundReason;
    final body = l10n.swapDepositRefundedBody(amount, from.symbol);
    return reason == null ? body : '$body\n\n${l10n.swapDepositRefundReason(reason)}';
  }

  Widget _depositBody(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, NumberFormattingService fmt) {
    final quote = _order.quote;
    final from = quote.fromToken;
    final address = _order.depositAddress;
    final deadline = TimeOfDay.fromDateTime(quote.deadline.toLocal()).format(context);
    return Column(
      children: [
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
            Text(
              fmt.formatAmount(quote.amountIn, decimals: from.decimals),
              style: text.amountHero.copyWith(color: colors.textContent),
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
          onTap: () => context.copyTextWithToaster(address, message: l10n.swapDepositAddressCopied),
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
                onTap: () => context.copyTextWithToaster(address, message: l10n.swapDepositAddressCopied),
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
                onTap: () => shareText(context, l10n.swapDepositShareContent(from.network, from.symbol, address)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          l10n.swapDepositNotice(from.symbol, from.network),
          style: text.caption.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _processingBody(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, String body) {
    return Column(
      children: [
        const SizedBox(height: 80),
        Loader(color: colors.semanticSage),
        const SizedBox(height: 32),
        Text(l10n.swapDepositProcessingTitle, style: text.titleScreen.copyWith(color: colors.textContent)),
        const SizedBox(height: 12),
        Text(
          body,
          style: text.bodyLarge.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _completedBody(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, NumberFormattingService fmt) {
    final to = _order.quote.toToken;
    final amount = fmt.formatAmount(_order.amountOut ?? _order.quote.amountOut, decimals: to.decimals);
    return Column(
      children: [
        const SizedBox(height: 80),
        const SuccessCheck(),
        const SizedBox(height: 32),
        Text(l10n.swapDepositCompleteTitle, style: text.titleSuccess.copyWith(color: colors.textContent)),
        const SizedBox(height: 12),
        Text(
          l10n.swapDepositCompleteBody(amount, to.symbol),
          style: text.bodyLarge.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _outcome(
    AppColorsV3 colors,
    AppTextThemeV3 text, {
    required Widget icon,
    required String title,
    required String body,
  }) {
    return Column(
      children: [
        const SizedBox(height: 80),
        icon,
        const SizedBox(height: 32),
        Text(
          title,
          style: text.titleScreen.copyWith(color: colors.textContent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          body,
          style: text.bodyLarge.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _doneButton(AppLocalizations l10n) {
    return QuantusButton.simple(
      label: l10n.swapDepositDone,
      onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
      variant: ButtonVariant.staged,
    );
  }
}
