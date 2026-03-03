import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/screens/swap/refund_address_picker_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/swap/review_quote_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/swap/token_picker_sheet.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  static const _smallGlassAsset = 'assets/v2/glass_40.png';
  static const _qrIconAsset = 'assets/v2/swap_qr_code.svg';
  static const _historyIconAsset = 'assets/v2/swap_clock_counter_clockwise.svg';
  static const _swapDirectionIconAsset = 'assets/v2/swap_arrows_down_up.svg';

  final _swapService = SwapService();
  final _fromController = TextEditingController();
  final _addressController = TextEditingController();
  SwapToken _fromToken = SwapService.availableTokens.first;
  double _toAmount = 0;
  double _fromUsd = 0;
  double _toUsd = 0;
  bool _loading = false;

  double get _rate => _swapService.getRate(_fromToken);
  String get _rateLabel {
    final val = 1 / _rate;
    if (val == 0) return '1 QUAN = 0 ${_fromToken.symbol}';
    final decimals = val >= 100
        ? 2
        : val >= 1
        ? 4
        : val >= 0.01
        ? 6
        : val >= 0.0001
        ? 8
        : 10;
    var formatted = val.toStringAsFixed(decimals).replaceAll(RegExp(r'0+$'), '');
    if (formatted.endsWith('.')) formatted = formatted.substring(0, formatted.length - 1);
    return '1 QUAN = $formatted ${_fromToken.symbol}';
  }

  @override
  void initState() {
    super.initState();
    _fromController.addListener(_recalculate);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _recalculate() {
    final amount = double.tryParse(_fromController.text) ?? 0;
    setState(() {
      _toAmount = amount * _rate;
      _fromUsd = amount * _swapService.getUsdPrice(_fromToken);
      _toUsd = _toAmount * _swapService.getUsdPrice(_swapService.getQuToken());
    });
  }

  bool get _canGetQuote =>
      _fromController.text.isNotEmpty &&
      (double.tryParse(_fromController.text) ?? 0) > 0 &&
      _addressController.text.isNotEmpty;

  Future<void> _getQuote() async {
    final amount = double.tryParse(_fromController.text) ?? 0;
    if (amount <= 0 || _addressController.text.isEmpty) return;

    setState(() => _loading = true);
    try {
      final quote = await _swapService.getQuote(fromToken: _fromToken, fromAmount: amount);
      if (!mounted) return;
      setState(() => _loading = false);
      _swapService.addRefundAddress(_fromToken.network, _addressController.text.trim());
      showReviewQuoteSheet(context, quote, _addressController.text);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _pickToken() async {
    final token = await showTokenPickerSheet(
      context,
      current: _fromToken,
      loadTokens: ({bool forceRefresh = false}) => _swapService.getFromTokens(limit: 10, forceRefresh: forceRefresh),
    );
    if (!mounted) return;
    if (token != null && token != _fromToken) {
      setState(() => _fromToken = token);
      _recalculate();
    }
  }

  void _scanQr() async {
    final address = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (address != null && mounted) {
      _addressController.text = address;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

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
                const SizedBox(height: 64),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fromSection(colors, text),
                        const SizedBox(height: 32),
                        _refundAddressSection(colors, text),
                        const SizedBox(height: 32),
                        _swapDivider(colors),
                        const SizedBox(height: 32),
                        _toSection(colors, text),
                        const SizedBox(height: 32),
                        _infoSection(colors, text),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _quoteButton(colors, text),
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

  Widget _fromSection(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('From', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _fromController,
                  style: text.mediumTitle?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: SwapService.formatTokenAmountHint(_fromToken),
                    hintStyle: text.mediumTitle?.copyWith(color: colors.textTertiary, fontWeight: FontWeight.bold),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _pickToken,
              child: SizedBox(
                width: 119,
                child: GlassContainer(
                  asset: GlassContainer.mediumAsset,
                  filled: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      TokenIcon(token: _fromToken, size: 25, networkBadgeSize: 10),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fromToken.symbol,
                              style: text.detail?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _fromToken.network,
                              style: text.tiny?.copyWith(color: colors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, color: colors.textSecondary, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('\$${_fromUsd.toStringAsFixed(2)}', style: text.detail?.copyWith(color: colors.textSecondary)),
            const SizedBox(width: 4),
            Icon(Icons.swap_vert, color: colors.textSecondary, size: 12),
          ],
        ),
      ],
    );
  }

  Widget _refundAddressSection(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Refund Address', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, color: colors.textSecondary, size: 14),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addressController,
                  style: text.smallParagraph?.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '${_fromToken.network} Address',
                    hintStyle: text.smallParagraph?.copyWith(color: colors.textTertiary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _scanQr,
                child: _smallGlassIconButton(colors: colors, iconAsset: _qrIconAsset),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final address = await showRefundAddressPickerSheet(context, _fromToken.network);
                  if (address != null) {
                    _addressController.text = address;
                    setState(() {});
                  }
                },
                child: _smallGlassIconButton(colors: colors, iconAsset: _historyIconAsset),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _swapDivider(AppColorsV2 colors) {
    return Row(
      children: [
        Expanded(child: Divider(color: colors.separator)),
        SizedBox(
          width: 40,
          height: 40,
          child: _smallGlassIconButton(colors: colors, iconAsset: _swapDirectionIconAsset),
        ),
        Expanded(child: Divider(color: colors.separator)),
      ],
    );
  }

  Widget _smallGlassIconButton({required AppColorsV2 colors, required String iconAsset}) {
    return SizedBox(
      width: 40,
      height: 40,
      child: GlassContainer(
        asset: _smallGlassAsset,
        child: Center(
          child: SvgPicture.asset(
            iconAsset,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _toSection(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('To', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.centerLeft,
                child: Text(
                  SwapService.formatTokenAmount(_toAmount, _swapService.getQuToken()),
                  style: text.mediumTitle?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _toAmount > 0 ? colors.textPrimary : colors.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 119,
              height: 56,
              child: GlassContainer(
                asset: GlassContainer.mediumAsset,
                filled: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'QUAN',
                      style: text.smallParagraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('\$${_toUsd.toStringAsFixed(2)}', style: text.detail?.copyWith(color: colors.textSecondary)),
      ],
    );
  }

  Widget _infoSection(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Slippage Tolerance', style: text.detail?.copyWith(color: colors.textSecondary)),
            Row(
              children: [
                Text('1%', style: text.detail?.copyWith(color: colors.textSecondary)),
                const SizedBox(width: 4),
                Icon(Icons.settings, color: colors.textSecondary, size: 12),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Rate', style: text.detail?.copyWith(color: colors.textSecondary)),
            Text(
              _rateLabel,
              style: text.detail?.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quoteButton(AppColorsV2 colors, AppTextTheme text) {
    final enabled = _canGetQuote && !_loading;
    return Button.label(label: 'Get a Quote', onTap: _getQuote, isDisabled: !enabled, variant: ButtonVariant.secondary);
  }
}
