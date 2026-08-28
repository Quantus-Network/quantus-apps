import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class DepositScreen extends ConsumerStatefulWidget {
  final SwapOrder order;
  const DepositScreen({super.key, required this.order});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _swapService = SwapService();
  late SwapOrder _order;
  bool _confirming = false;

  /// This swap flow is demo-only — no real deposit is ever expected. To make it
  /// impossible to accidentally send funds, the QR code, the on-screen address,
  /// and the copy/share actions all surface this warning instead of the real
  /// deposit address. Scanning the QR decodes to this plain text, not an
  /// address, so no wallet can act on it.
  static const String _demoWarningPayload = 'demo only - do not send funds';

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _confirmSent() async {
    setState(() => _confirming = true);
    try {
      final updated = await _swapService.confirmFundsSent(_order.orderId);
      if (!mounted) return;
      setState(() {
        _order = updated;
        _confirming = false;
      });
      _pollStatus();
    } catch (e) {
      quantusPrint('Confirm funds sent failed: $e');
      setState(() => _confirming = false);
    }
  }

  Future<void> _pollStatus() async {
    while (mounted && _order.status == SwapStatus.processing) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final updated = await _swapService.getSwapStatus(_order.orderId);
        if (!mounted) return;
        setState(() => _order = updated);
      } catch (e) {
        quantusPrint('Swap status poll failed: $e');
      }
    }
  }

  void _copyAddress(AppLocalizations l10n) {
    // Demo-only: never expose the real deposit address (see _demoWarningPayload).
    context.copyTextWithToaster(_demoWarningPayload);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final quote = _order.quote;
    final usd = quote.fromAmount * _swapService.getUsdPrice(quote.fromToken);

    return ScaffoldBase(
      appBar: V2AppBar(
        title: l10n.swapTitle,
        trailing: Icon(Icons.info_outline, color: colors.textContent, size: 24),
      ),
      mainContent: Column(
        children: [
          if (_order.status == SwapStatus.complete)
            _completedBody(l10n, colors, text)
          else if (_order.status == SwapStatus.processing)
            _processingBody(l10n, colors, text)
          else
            _depositBody(l10n, colors, text, quote, usd),
          const Spacer(),
          if (_order.status == SwapStatus.depositing) _sentButton(l10n),
          if (_order.status == SwapStatus.complete) _doneButton(l10n),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _depositBody(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, SwapQuote quote, double usd) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.swapDepositAmount, style: text.body.copyWith(color: colors.textContent)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => context.copyTextWithToaster(
                SwapService.formatTokenAmount(quote.totalAmount, quote.fromToken),
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
            TokenIcon(token: quote.fromToken, size: 28, networkBadgeSize: 11),
            const SizedBox(width: 8),
            Text(
              SwapService.formatTokenAmount(quote.totalAmount, quote.fromToken),
              style: text.amountHero.copyWith(color: colors.textContent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('\$${usd.toStringAsFixed(2)}', style: text.body.copyWith(color: colors.textMuted)),
        const SizedBox(height: 40),
        ClipRRect(
          borderRadius: context.radiusV3.smBorder,
          child: Container(
            color: colors.textWhite,
            padding: const EdgeInsets.all(8),
            child: QrImageView(data: _demoWarningPayload, version: QrVersions.auto, size: 184),
          ),
        ),
        const SizedBox(height: 16),
        // SizedBox(
        //   width: 264,
        //   child: Stack(
        //     children: [
        //       Text(
        //         _demoWarningPayload,
        //         style: text.smallParagraph?.copyWith(
        //           color: colors.textPrimary,
        //           fontWeight: FontWeight.w500,
        //           height: 1.35,
        //         ),
        //         textAlign: TextAlign.center,
        //       ),
        //       Positioned(
        //         right: 0,
        //         top: 19,
        //         child: GestureDetector(
        //           onTap: () => _copyAddress(l10n),
        //           child: Container(
        //             width: 20,
        //             height: 20,
        //             decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(4)),
        //             child: Center(child: Icon(Icons.copy, color: colors.textPrimary, size: 12)),
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        const SizedBox(height: 16),
        Text(
          l10n.swapDepositDemoWarning,
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
                onTap: () => _copyAddress(l10n),
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
                onTap: () {
                  shareText(
                    context,
                    l10n.swapDepositShareContent(
                      _order.quote.fromToken.network,
                      _order.quote.fromToken.symbol,
                      _demoWarningPayload,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text(
          l10n.swapDepositNotice(quote.fromToken.symbol, quote.fromToken.network),
          style: text.caption.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _processingBody(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text) {
    return Column(
      children: [
        const SizedBox(height: 80),
        Loader(color: colors.semanticSage),
        const SizedBox(height: 32),
        Text(l10n.swapDepositProcessingTitle, style: text.titleScreen.copyWith(color: colors.textContent)),
        const SizedBox(height: 12),
        Text(l10n.swapDepositProcessingBody, style: text.bodyLarge.copyWith(color: colors.textMuted)),
      ],
    );
  }

  Widget _completedBody(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text) {
    final amount = SwapService.formatTokenAmount(_order.quote.toAmount, _order.quote.toToken);

    return Column(
      children: [
        const SizedBox(height: 80),
        const SuccessCheck(),
        const SizedBox(height: 32),
        Text(l10n.swapDepositCompleteTitle, style: text.titleSuccess.copyWith(color: colors.textContent)),
        const SizedBox(height: 12),
        Text(
          l10n.swapDepositCompleteBody(amount, AppConstants.tokenSymbol),
          style: text.bodyLarge.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Text(
          l10n.swapDemoOnly,
          style: text.titleHero.copyWith(color: colors.accentFlare),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.swapDemoOnlyBody,
          style: text.bodyLarge.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _sentButton(AppLocalizations l10n) {
    return QuantusButton.simple(
      label: l10n.swapDepositSentFunds,
      onTap: _confirmSent,
      variant: ButtonVariant.staged,
      isLoading: _confirming,
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
