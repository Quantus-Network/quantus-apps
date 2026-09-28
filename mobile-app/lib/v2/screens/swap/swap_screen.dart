import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/near_intents_attribution.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/review_swap_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_address_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_slippage_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/swap/token_picker_sheet.dart';

/// Swaps between QTC in [account] and a token on another chain, either way.
class SwapScreen extends ConsumerStatefulWidget {
  final Account account;

  const SwapScreen({super.key, required this.account});

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen> {
  static const _directionIconAsset = 'assets/v2/swap_arrows_down_up.svg';
  static const _slippageIconAsset = 'assets/v2/swap_pencil.svg';
  static const _amountBoxWidth = 125.0;
  static const _rowHeight = 44.0;

  final _amountController = TextEditingController();
  SwapToken? _foreign;
  SwapToken? _listedQuantus;
  bool _loadingTokens = true;
  bool _swapOut = true;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    _loadTokens();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadTokens({bool forceRefresh = false}) async {
    setState(() => _loadingTokens = true);
    try {
      final service = ref.read(swapServiceProvider);
      final tokens = await service.getFromTokens(forceRefresh: forceRefresh);
      final listedQuantus = await service.getListedQuantusToken();
      if (!mounted) return;
      setState(() {
        _foreign ??= tokens.first;
        _listedQuantus = listedQuantus;
      });
    } catch (e) {
      quantusPrint('Swap tokens failed to load: $e');
    } finally {
      if (mounted) setState(() => _loadingTokens = false);
    }
  }

  BigInt _amountIn(SwapToken from) =>
      ref.read(numberFormattingServiceProvider).parseAmount(_amountController.text, decimals: from.decimals) ??
      BigInt.zero;

  void _setDirection({required bool swapOut}) {
    if (swapOut == _swapOut) return;
    setState(() => _swapOut = swapOut);
    _amountController.clear();
  }

  /// Picks the external token. Picking from the QTC side moves QTC to the other side.
  Future<void> _pickToken(SwapToken tapped) async {
    final service = ref.read(swapServiceProvider);
    final foreign = _foreign!;
    final token = await showTokenPickerSheet(
      context,
      current: foreign,
      loadTokens: ({bool forceRefresh = false}) => service.getFromTokens(limit: 10, forceRefresh: forceRefresh),
    );
    if (token == null || !mounted) return;
    setState(() => _foreign = token);
    if (tapped.isQuantus) _setDirection(swapOut: !_swapOut);
  }

  Future<void> _addAddress(SwapToken from, SwapToken to, SwapToken foreign) async {
    final service = ref.read(swapServiceProvider);
    final account = widget.account;
    final amount = _amountIn(from);
    final swapOut = _swapOut;
    final quote = await showSwapAddressSheet(
      context,
      token: foreign,
      role: swapOut ? SwapAddressRole.recipient : SwapAddressRole.refund,
      quote: (address) => service.getQuote(
        from: from,
        to: to,
        amount: amount,
        refundAddress: swapOut ? account.accountId : address,
        recipient: swapOut ? address : account.accountId,
        slippageBps: ref.read(swapSlippageBpsProvider),
      ),
    );
    if (quote == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSwapScreen(account: account, quote: quote),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final foreign = _foreign;
    final SwapToken quantus = _listedQuantus ?? ref.watch(quantusSwapTokenProvider);

    return ScaffoldBase(
      appBar: V2AppBar(
        title: l10n.swapTitle,
        slotWidth: NearIntentsAttribution.width,
        trailing: const NearIntentsAttribution(),
      ),
      mainContent: foreign == null
          ? _tokensState(l10n, colors, text)
          : _form(l10n, colors, text, _swapOut ? quantus : foreign, _swapOut ? foreign : quantus),
      bottomContent: foreign == null
          ? null
          : _cta(l10n, _swapOut ? quantus : foreign, _swapOut ? foreign : quantus, foreign),
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

  Widget _cta(AppLocalizations l10n, SwapToken from, SwapToken to, SwapToken foreign) {
    final amountIn = _amountIn(from);
    final spendable = _swapOut ? ref.watch(effectiveMaxBalanceProviderFamily(widget.account.accountId)).value : null;
    final insufficient = spendable != null && amountIn > spendable;
    return ScaffoldBaseBottomContent(
      child: QuantusButton.simple(
        label: insufficient
            ? l10n.sendLogicInsufficientBalance
            : _swapOut
            ? l10n.swapAddRecipientAddress
            : l10n.swapAddRefundAddress,
        onTap: () => _addAddress(from, to, foreign),
        isDisabled: amountIn == BigInt.zero || insufficient,
      ),
    );
  }

  Widget _form(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, SwapToken from, SwapToken to) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amountIn = _amountIn(from);
    final estimateOut = swapEstimateOut(amountIn, from, to);
    final oneFrom = BigInt.from(10).pow(from.decimals);
    final priced = from.usdPrice > 0 && to.usdPrice > 0;
    final wallet = widget.account.name;
    final external = l10n.swapExternalWallet;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.pillBorder),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  children: [
                    _section(
                      colors,
                      text,
                      label: l10n.swapFrom,
                      owner: _swapOut ? wallet : external,
                      token: from,
                      usd: swapUsdValue(amountIn, from),
                      amount: _amountField(colors, text, from),
                    ),
                    Container(height: 4, color: colors.bgVoid),
                    _section(
                      colors,
                      text,
                      label: l10n.swapTo,
                      owner: _swapOut ? external : wallet,
                      token: to,
                      usd: swapUsdValue(estimateOut, to),
                      amount: _amountBox(
                        colors,
                        Text(
                          fmt.formatAmount(estimateOut, decimals: to.decimals),
                          style: text.amountInline.copyWith(
                            color: estimateOut > BigInt.zero ? colors.textContent : colors.textMuted2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _setDirection(swapOut: !_swapOut),
                  child: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: colors.bgVoid, shape: BoxShape.circle),
                    child: SvgPicture.asset(
                      _directionIconAsset,
                      colorFilter: ColorFilter.mode(colors.textContent, BlendMode.srcIn),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (priced)
                Expanded(
                  child: Text(
                    l10n.swapRateLabel(
                      from.symbol,
                      fmt.formatAmount(swapEstimateOut(oneFrom, from, to), decimals: to.decimals),
                      to.symbol,
                    ),
                    style: text.bodyEmphasis.copyWith(color: colors.textMuted2),
                  ),
                )
              else
                const Spacer(),
              GestureDetector(
                onTap: () => showSwapSlippageSheet(context),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.swapSlippageLabel(slippagePercentLabel(ref.watch(swapSlippageBpsProvider))),
                      style: text.bodyEmphasis.copyWith(color: colors.textMuted2),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colors.bgVoid,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: SvgPicture.asset(
                        _slippageIconAsset,
                        colorFilter: ColorFilter.mode(colors.textContent, BlendMode.srcIn),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(
    AppColorsV3 colors,
    AppTextThemeV3 text, {
    required String label,
    required String owner,
    required SwapToken token,
    required double usd,
    required Widget amount,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: text.labelData.copyWith(color: colors.textMuted)),
              Text(owner, style: text.caption.copyWith(color: colors.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: _tokenPill(colors, text, token)),
              ),
              const SizedBox(width: 12),
              amount,
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text('\$${usd.toStringAsFixed(2)}', style: text.body.copyWith(color: colors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _tokenPill(AppColorsV3 colors, AppTextThemeV3 text, SwapToken token) {
    return SizedBox(
      height: _rowHeight,
      child: QuantusButton(
        width: null,
        centered: false,
        variant: ButtonVariant.glass,
        onTap: () => _pickToken(token),
        padding: const EdgeInsets.only(left: 6, right: 12),
        borderRadius: context.radiusV3.pillBorder,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TokenIcon(token: token, size: 32, networkBadgeSize: 12),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.symbol,
                    style: text.bodyEmphasis.copyWith(color: colors.textContent),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    token.networkName,
                    style: text.caption.copyWith(color: colors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            QuantusIcon(QuantusIcons.caretDown, color: colors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _amountBox(AppColorsV3 colors, Widget child) {
    return Container(
      width: _amountBoxWidth,
      height: _rowHeight,
      padding: const EdgeInsets.only(left: 12, right: 8),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(color: colors.textWhite.useOpacity(0.05), borderRadius: context.radiusV3.smBorder),
      child: child,
    );
  }

  Widget _amountField(AppColorsV3 colors, AppTextThemeV3 text, SwapToken from) {
    return _amountBox(
      colors,
      TextField(
        controller: _amountController,
        textAlign: TextAlign.right,
        style: text.amountInline.copyWith(color: colors.textContent),
        cursorColor: colors.accentFlare,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          DecimalInputFilter(localeConfig: ref.watch(localeNumberConfigProvider), maxDecimalPlaces: from.decimals),
        ],
        decoration: InputDecoration.collapsed(
          hintText: '0',
          hintStyle: text.amountInline.copyWith(color: colors.textMuted2),
        ),
      ),
    );
  }
}
