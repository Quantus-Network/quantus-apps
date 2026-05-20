import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

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
      debugPrint('Confirm funds sent failed: $e');
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
        debugPrint('Swap status poll failed: $e');
      }
    }
  }

  // Currently this is only for demo purposes
  // We just return the demo warning for now
  String _getDepositAddress(AppLocalizations l10n) {
    return l10n.swapDepositDemoWarning;
  }

  void _copyAddress(AppLocalizations l10n) {
    context.copyTextWithToaster(_getDepositAddress(l10n));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final quote = _order.quote;
    final usd = quote.fromAmount * _swapService.getUsdPrice(quote.fromToken);

    return ScaffoldBase(
      appBar: V2AppBar(
        title: l10n.swapTitle,
        trailing: Icon(Icons.info_outline, color: colors.textPrimary, size: 24),
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
          if (_order.status == SwapStatus.depositing) _sentButton(l10n, colors, text),
          if (_order.status == SwapStatus.complete) _doneButton(l10n, colors, text),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _depositBody(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text, SwapQuote quote, double usd) {
    final demoWarning = l10n.swapDepositDemoWarning;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.swapDepositAmount, style: text.smallParagraph?.copyWith(color: colors.textPrimary, height: 1.35)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => context.copyTextWithToaster(
                SwapService.formatTokenAmount(quote.totalAmount, quote.fromToken),
                message: l10n.swapDepositAmountCopied,
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(4)),
                child: Center(child: Icon(Icons.copy, color: colors.textPrimary, size: 12)),
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
              style: text.mediumTitle?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '\$${usd.toStringAsFixed(2)}',
          style: text.smallParagraph?.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 40),
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: QrImageView(data: 'Quantum secure bitcoin - quantus!', version: QrVersions.auto, size: 184),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 264,
          child: Stack(
            children: [
              Text(
                demoWarning,
                style: text.smallParagraph?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              Positioned(
                right: 0,
                top: 19,
                child: GestureDetector(
                  onTap: () => _copyAddress(l10n),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(4)),
                    child: Center(child: Icon(Icons.copy, color: colors.textPrimary, size: 12)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: QuantusButton.simple(
                label: l10n.receiveCopy,
                variant: ButtonVariant.transparent,
                onTap: () => _copyAddress(l10n),
                icon: Icon(Icons.copy, color: colors.textPrimary, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: QuantusButton.simple(
                label: l10n.swapDepositShareQr,
                icon: Icon(Icons.qr_code, color: colors.textPrimary, size: 20),
                variant: ButtonVariant.transparent,
                onTap: () {
                  shareText(
                    context,
                    l10n.swapDepositShareContent(
                      _order.quote.fromToken.network,
                      _order.quote.fromToken.symbol,
                      _getDepositAddress(l10n),
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
          style: text.detail?.copyWith(color: colors.textSecondary, height: 1.35),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _processingBody(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        const SizedBox(height: 80),
        Loader(color: colors.accentGreen),
        const SizedBox(height: 32),
        Text(
          l10n.swapDepositProcessingTitle,
          style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20),
        ),
        const SizedBox(height: 12),
        Text(l10n.swapDepositProcessingBody, style: text.paragraph?.copyWith(color: colors.textSecondary)),
      ],
    );
  }

  Widget _completedBody(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    final amount = SwapService.formatTokenAmount(_order.quote.toAmount, _order.quote.toToken);

    return Column(
      children: [
        const SizedBox(height: 80),
        const SuccessCheck(),
        const SizedBox(height: 32),
        Text(l10n.swapDepositCompleteTitle, style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
        const SizedBox(height: 12),
        Text(
          l10n.swapDepositCompleteBody(amount),
          style: text.paragraph?.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        if (AppConstants.stillOnTestnet)
          Text(
            l10n.swapDepositTestnetBanner,
            style: text.paragraph?.copyWith(color: Colors.yellow),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _sentButton(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    return QuantusButton.simple(
      label: l10n.swapDepositSentFunds,
      onTap: _confirmSent,
      variant: ButtonVariant.secondary,
      isLoading: _confirming,
    );
  }

  Widget _doneButton(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    return QuantusButton.simple(
      label: l10n.swapDepositDone,
      onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
      variant: ButtonVariant.secondary,
    );
  }
}
