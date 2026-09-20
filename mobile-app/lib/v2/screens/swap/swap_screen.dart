import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/refund_address_picker_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/swap/review_quote_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/token_picker_sheet.dart';

class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({super.key});

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen> {
  static const _qrIconAsset = 'assets/v2/swap_qr_code.svg';
  static const _historyIconAsset = 'assets/v2/swap_clock_counter_clockwise.svg';
  static const _swapDirectionIconAsset = 'assets/v2/swap_arrows_down_up.svg';

  final _fromController = TextEditingController();
  final _addressController = TextEditingController();
  SwapToken? _fromToken;
  bool _loadingTokens = true;
  bool _quoting = false;

  @override
  void initState() {
    super.initState();
    _fromController.addListener(() => setState(() {}));
    _loadTokens();
  }

  @override
  void dispose() {
    _fromController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadTokens({bool forceRefresh = false}) async {
    setState(() => _loadingTokens = true);
    try {
      final tokens = await ref.read(swapServiceProvider).getFromTokens(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() => _fromToken ??= tokens.first);
    } catch (e) {
      quantusPrint('Swap tokens failed to load: $e');
    } finally {
      if (mounted) setState(() => _loadingTokens = false);
    }
  }

  BigInt _amountIn(SwapToken from) =>
      ref.read(numberFormattingServiceProvider).parseAmount(_fromController.text, decimals: from.decimals) ??
      BigInt.zero;

  static double _usd(BigInt amount, SwapToken token) => amount.toDouble() / pow(10, token.decimals) * token.usdPrice;

  static BigInt _estimateOut(BigInt amountIn, SwapToken from, SwapToken to) {
    if (to.usdPrice <= 0) return BigInt.zero;
    return BigInt.from(_usd(amountIn, from) / to.usdPrice * pow(10, to.decimals));
  }

  static String _amountHint(SwapToken token) => token.decimals == 0 ? '0' : '0.${'0' * token.decimals.clamp(1, 8)}';

  String _rateLabel(AppLocalizations l10n, SwapToken from, SwapToken to) {
    if (from.usdPrice <= 0 || to.usdPrice <= 0) return l10n.swapRateZero(from.symbol, to.symbol);
    final val = to.usdPrice / from.usdPrice;
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
    return l10n.swapRateLabel(formatted, from.symbol, to.symbol);
  }

  Future<void> _getQuote(SwapToken from, SwapToken to) async {
    final refund = _addressController.text.trim();
    final recipient = ref.read(activeAccountProvider).value!.account.accountId;
    final service = ref.read(swapServiceProvider);
    setState(() => _quoting = true);
    try {
      final quote = await service.getQuote(
        from: from,
        to: to,
        amount: _amountIn(from),
        refundAddress: refund,
        recipient: recipient,
      );
      await service.addRefundAddress(from.network, refund);
      if (!mounted) return;
      showReviewQuoteSheet(context, quote);
    } catch (e) {
      quantusPrint('Swap quote failed: $e');
      if (!mounted) return;
      context.showErrorToaster(message: ref.read(l10nProvider).swapQuoteError(describeSwapError(e)));
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  void _pickToken(SwapToken from) async {
    final service = ref.read(swapServiceProvider);
    final token = await showTokenPickerSheet(
      context,
      current: from,
      loadTokens: ({bool forceRefresh = false}) => service.getFromTokens(limit: 10, forceRefresh: forceRefresh),
    );
    if (!mounted) return;
    if (token != null && token != from) setState(() => _fromToken = token);
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
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final from = _fromToken;
    final to = ref.watch(quantusSwapTokenProvider);

    return ScaffoldBase(
      appBar: V2AppBar(
        title: l10n.swapTitle,
        trailing: Icon(Icons.info_outline, color: colors.textContent, size: 24),
      ),
      mainContent: from == null ? _tokensState(l10n, colors, text) : _form(l10n, colors, text, from, to),
    );
  }

  Widget _tokensState(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text) {
    if (_loadingTokens) return const Center(child: Loader());
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.swapTokenPickerLoadError, style: text.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _loadTokens(forceRefresh: true),
            child: Text(l10n.commonTryAgain, style: text.body.copyWith(color: colors.accentFlare)),
          ),
        ],
      ),
    );
  }

  Widget _form(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, SwapToken from, SwapToken to) {
    final amountIn = _amountIn(from);
    final estimateOut = _estimateOut(amountIn, from, to);
    final enabled = amountIn > BigInt.zero && _addressController.text.trim().isNotEmpty && !_quoting;
    return Column(
      children: [
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fromSection(l10n, colors, text, from, amountIn),
                const SizedBox(height: 32),
                _refundAddressSection(l10n, colors, text, from),
                const SizedBox(height: 32),
                _swapDivider(colors),
                const SizedBox(height: 32),
                _toSection(l10n, colors, text, to, estimateOut),
                const SizedBox(height: 32),
                _infoSection(l10n, colors, text, from, to),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        QuantusButton.simple(
          label: l10n.swapGetQuote,
          onTap: () => _getQuote(from, to),
          isDisabled: !enabled,
          isLoading: _quoting,
          variant: ButtonVariant.staged,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _fromSection(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, SwapToken from, BigInt amountIn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.swapFrom, style: text.body.copyWith(color: colors.textContent)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: _fromController,
                  style: text.amountHero.copyWith(color: colors.textContent),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: _amountHint(from),
                    hintStyle: text.amountHero.copyWith(color: colors.textMuted2),
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
            SizedBox(
              width: 119,
              height: 56,
              child: QuantusButton(
                centered: false,
                variant: ButtonVariant.glass,
                onTap: () => _pickToken(from),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                borderRadius: context.radiusV3.mdBorder,
                child: Row(
                  children: [
                    TokenIcon(token: from, size: 25, networkBadgeSize: 10),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            from.symbol,
                            style: text.caption.copyWith(color: colors.textContent),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            from.network,
                            style: text.caption.copyWith(color: colors.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    QuantusIcon(QuantusIcons.caretDown, color: colors.textMuted, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('\$${_usd(amountIn, from).toStringAsFixed(2)}', style: text.caption.copyWith(color: colors.textMuted)),
            const SizedBox(width: 4),
            QuantusIcon(QuantusIcons.swapVertical, color: colors.textMuted, size: 12),
          ],
        ),
      ],
    );
  }

  Widget _refundAddressSection(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, SwapToken from) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.swapRefundAddress, style: text.body.copyWith(color: colors.textContent)),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, color: colors.textMuted, size: 14),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
          padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addressController,
                  style: text.dataAddressLarge.copyWith(color: colors.textContent),
                  decoration: InputDecoration(
                    hintText: l10n.swapRefundAddressHint(from.network),
                    hintStyle: text.dataAddressLarge.copyWith(color: colors.textMuted),
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
              _smallIconButton(colors: colors, iconAsset: _qrIconAsset, onTap: _scanQr),
              const SizedBox(width: 8),
              _smallIconButton(
                colors: colors,
                iconAsset: _historyIconAsset,
                onTap: () async {
                  final address = await showRefundAddressPickerSheet(context, from.network);
                  if (address != null) {
                    _addressController.text = address;
                    setState(() {});
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _swapDivider(AppColorsV3 colors) {
    return Row(
      children: [
        const Expanded(child: MenuDivider()),
        SizedBox(
          width: 40,
          height: 40,
          child: _smallIconButton(colors: colors, iconAsset: _swapDirectionIconAsset, onTap: () {}),
        ),
        const Expanded(child: MenuDivider()),
      ],
    );
  }

  Widget _smallIconButton({required AppColorsV3 colors, required String iconAsset, VoidCallback? onTap}) {
    return SizedBox(
      width: 40,
      height: 40,
      child: QuantusButton(
        onTap: onTap,
        variant: ButtonVariant.glass,
        padding: EdgeInsets.zero,
        borderRadius: context.radiusV3.smBorder,
        child: Center(
          child: SvgPicture.asset(
            iconAsset,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(colors.textContent, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  Widget _toSection(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, SwapToken to, BigInt estimateOut) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.swapTo, style: text.body.copyWith(color: colors.textContent)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
                alignment: Alignment.centerLeft,
                child: Text(
                  fmt.formatAmount(estimateOut, decimals: to.decimals),
                  style: text.amountHero.copyWith(
                    color: estimateOut > BigInt.zero ? colors.textContent : colors.textMuted2,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 119,
              height: 56,
              child: QuantusButton(
                centered: false,
                variant: ButtonVariant.glass,
                onTap: () {},
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                borderRadius: context.radiusV3.mdBorder,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TokenIcon(token: to, size: 25, networkBadgeSize: 10),
                    const SizedBox(width: 8),
                    Text(to.symbol, style: text.body.copyWith(color: colors.textContent)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('\$${_usd(estimateOut, to).toStringAsFixed(2)}', style: text.caption.copyWith(color: colors.textMuted)),
      ],
    );
  }

  Widget _infoSection(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, SwapToken from, SwapToken to) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.swapSlippageTolerance, style: text.caption.copyWith(color: colors.textMuted)),
            Row(
              children: [
                Text(
                  '${slippagePercentLabel(SwapService.defaultSlippageBps)}%',
                  style: text.caption.copyWith(color: colors.textMuted),
                ),
                const SizedBox(width: 4),
                Icon(Icons.settings, color: colors.textMuted, size: 12),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.swapRate, style: text.caption.copyWith(color: colors.textMuted)),
            Text(_rateLabel(l10n, from, to), style: text.caption.copyWith(color: colors.textMuted)),
          ],
        ),
      ],
    );
  }
}
