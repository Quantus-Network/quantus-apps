import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class DepositScreen extends StatefulWidget {
  final SwapOrder order;
  const DepositScreen({super.key, required this.order});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
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
      } catch (_) {}
    }
  }

  void _copyAddress() {
    Clipboard.setData(ClipboardData(text: _order.depositAddress));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Address copied'), duration: Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final quote = _order.quote;
    final usd = quote.fromAmount * _swapService.getUsdPrice(quote.fromToken);

    return Scaffold(
      backgroundColor: colors.background,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _header(colors, text),
                const SizedBox(height: 40),
                if (_order.status == SwapStatus.complete)
                  _completedBody(colors, text)
                else if (_order.status == SwapStatus.processing)
                  _processingBody(colors, text)
                else
                  _depositBody(colors, text, quote, usd),
                const Spacer(),
                if (_order.status == SwapStatus.depositing) _sentButton(colors, text),
                if (_order.status == SwapStatus.complete) _doneButton(colors, text),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppColorsV2 colors, AppTextTheme text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const AppBackButton(),
        Text('Swap', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
        Icon(Icons.info_outline, color: colors.textPrimary, size: 24),
      ],
    );
  }

  Widget _depositBody(AppColorsV2 colors, AppTextTheme text, SwapQuote quote, double usd) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Deposit Amount', style: text.smallParagraph?.copyWith(color: colors.textPrimary, height: 1.35)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: quote.totalAmount.toStringAsFixed(2))),
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
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: colors.accentPink.withValues(alpha: 0.3), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              quote.totalAmount.toStringAsFixed(2),
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

            /// for now this QR Code is invalid so people don't transfer by accident
            // child: QrImageView(data: _order.depositAddress, version: QrVersions.auto, size: 184),
            child: QrImageView(data: 'quantum secure bitcoin - quantus!', version: QrVersions.auto, size: 184),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 264,
          child: Stack(
            children: [
              // for now put invalid address so people don't transfer by accident
              Text(
                // _order.depositAddress.toLowerCase(),
                '-------------------',
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
                  onTap: _copyAddress,
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
              child: GlassContainer(
                filled: false,
                asset: GlassContainer.mediumAsset,
                onTap: _copyAddress,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copy, color: colors.textPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Copy',
                      style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GlassContainer(
                filled: false,
                asset: GlassContainer.mediumAsset,
                onTap: () {},
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code, color: colors.textPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Share QR',
                      style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Text.rich(
          TextSpan(
            style: text.detail?.copyWith(color: colors.textSecondary, height: 1.35),
            children: [
              const TextSpan(text: 'Use your '),
              TextSpan(
                text: quote.fromToken.symbol,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: ' or '),
              TextSpan(
                text: quote.fromToken.network,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: ' wallet to deposit funds. Depositing other assets may result in loss of funds.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _processingBody(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        const SizedBox(height: 80),
        CircularProgressIndicator(color: colors.accentGreen),
        const SizedBox(height: 32),
        Text('Processing Swap', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
        const SizedBox(height: 12),
        Text('This may take a few minutes...', style: text.paragraph?.copyWith(color: colors.textSecondary)),
      ],
    );
  }

  Widget _completedBody(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        const SizedBox(height: 80),
        const SuccessCheck(),
        const SizedBox(height: 32),
        Text('Swap Complete', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
        const SizedBox(height: 12),
        Text(
          'Your swap for ${_order.quote.toAmount.toStringAsFixed(2)} QUAN is processing.',
          style: text.paragraph?.copyWith(color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        if (AppConstants.stillOnTestnet)
          Text(
            'DEMO ONLY - WE ARE STILL ON TESTNET',
            style: text.paragraph?.copyWith(color: Colors.yellow),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _sentButton(AppColorsV2 colors, AppTextTheme text) {
    return GlassContainer(
      asset: GlassContainer.wideAsset,
      filled: false,
      onTap: _confirming ? null : _confirmSent,
      child: Center(
        child: _confirming
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: colors.textPrimary, strokeWidth: 2),
              )
            : Text(
                "I've sent the funds",
                style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
              ),
      ),
    );
  }

  Widget _doneButton(AppColorsV2 colors, AppTextTheme text) {
    return GlassContainer(
      asset: GlassContainer.wideAsset,
      filled: false,
      onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
      child: Center(
        child: Text(
          'Done',
          style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
