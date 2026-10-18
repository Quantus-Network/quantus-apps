import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/amount_box.dart';
import 'package:resonance_network_wallet/v2/components/near_intents_attribution.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/review_swap_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_address_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_slippage_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_summary.dart';
import 'package:resonance_network_wallet/v2/screens/swap/token_picker_sheet.dart';

/// What a swap out draws on: the account's balance, the most of it that can
/// go in once the deposit's fee is known, and a retry row when the fee failed.
typedef _Funds = ({AsyncValue<BigInt> balance, BigInt? max, Widget? feeFailed});

/// Swaps between QTC in [account] and a token on another chain, either way.
/// Only a transparent account whose key signs here swaps: QTC is refunded to
/// and paid out at its own address, which a wormhole address could not take.
/// Where NEAR Intents is not allowed, until 1Click lists QTC with a price, or
/// when 1Click cannot be reached, the form gives way to a notice that swaps
/// are unavailable.
class SwapScreen extends ConsumerStatefulWidget {
  final Account account;

  /// Whether to open as a sale of QTC rather than a purchase.
  final bool swapOut;

  const SwapScreen({super.key, required this.account, this.swapOut = false});

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen> {
  static const _directionIconAsset = 'assets/v2/swap_arrows_down_up.svg';
  static const _slippageIconAsset = 'assets/v2/swap_pencil.svg';
  static const _amountBoxWidth = 125.0;
  static const _rowHeight = 44.0;
  static const _chipShares = [25, 50, 75];

  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  SwapToken? _foreign;
  SwapToken? _quantus;
  bool _loadingTokens = true;
  bool _loadFailed = false;

  /// The external address the swap refunds to or pays out at, once given.
  String? _address;
  bool _quoting = false;

  /// Bumped on every change to what a quote is for, so a quote the form
  /// moved past while it was out opens nothing.
  int _edits = 0;

  /// A purchase of QTC puts the other token on top and QTC below.
  late bool _swapOut = widget.swapOut;

  /// Whether the amount typed is what the lower side receives, the upper
  /// side then paying what it costs, rather than what the upper side pays.
  bool _exactOutput = false;
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() => _edits++));
    _amountFocus.addListener(() => setState(() {}));
    _loadTokens();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  /// Loads the tokens from the current service. The form waits for the
  /// result, and a load that a newer one has overtaken is dropped, so a
  /// listing fetched before a config change can never come back.
  Future<void> _loadTokens({bool forceRefresh = false}) async {
    final load = ++_loads;
    setState(() {
      _loadingTokens = true;
      _loadFailed = false;
      _quantus = null;
    });
    try {
      final service = ref.read(swapServiceProvider);
      final tokens = await service.getFromTokens(forceRefresh: forceRefresh);
      final quantus = await service.getListedQuantusToken();
      if (!mounted || load != _loads) return;
      setState(() {
        _foreign ??= tokens.firstWhere((t) => !t.isQuantus);
        _quantus = quantus;
      });
    } catch (e) {
      quantusPrint('Swap tokens failed to load: $e');
      if (mounted && load == _loads) setState(() => _loadFailed = true);
    } finally {
      if (mounted && load == _loads) setState(() => _loadingTokens = false);
    }
  }

  /// What [from] pays and [to] receives: the amount typed on its side, and
  /// the other at listed prices.
  (BigInt, BigInt) _amounts(SwapToken from, SwapToken to) {
    final typed =
        ref
            .read(numberFormattingServiceProvider)
            .parseAmount(_amountController.text, decimals: (_exactOutput ? to : from).decimals) ??
        BigInt.zero;
    return _exactOutput ? (swapEstimateOut(typed, to, from), typed) : (typed, swapEstimateOut(typed, from, to));
  }

  void _setDirection({required bool swapOut}) {
    if (swapOut == _swapOut) return;
    setState(() {
      _swapOut = swapOut;
      _exactOutput = false;
      _edits++;
    });
    _amountController.clear();
  }

  /// Moves typing to the other side, starting from its estimate, selected so
  /// that typing replaces it.
  void _typeOtherSide(SwapToken from, SwapToken to) {
    final (amountIn, amountOut) = _amounts(from, to);
    final token = _exactOutput ? from : to;
    final estimate = _exactOutput ? amountIn : amountOut;
    final text = estimate == BigInt.zero ? '' : _amountText(estimate, token);
    setState(() => _exactOutput = !_exactOutput);
    _amountController.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    _amountFocus.requestFocus();
  }

  /// [amount] of [token] as it is typed into the field.
  String _amountText(BigInt amount, SwapToken token) => ref
      .read(numberFormattingServiceProvider)
      .formatBalance(amount, decimals: token.decimals, maxDecimals: token.decimals, addThousandsSeparators: false);

  /// Types [amount] as what the account pays.
  void _setAmount(BigInt amount, SwapToken from) {
    setState(() => _exactOutput = false);
    _amountController.text = _amountText(amount, from);
  }

  /// Null when the other side pays, as in a swap in or when the preflight
  /// stand-in's deposit is made by hand.
  _Funds? _funds() {
    if (!_swapOut || ref.watch(swapPreflightProvider) != null) return null;
    final balance = ref.watch(effectiveBalanceProviderFamily(widget.account.accountId));
    final spendable = balance.value;
    if (spendable == null) return (balance: balance, max: null, feeFailed: null);
    final key = (widget.account, spendable);
    final fee = ref.watch(swapDepositFeeProvider(key));
    final feeValue = fee.value;
    return (
      balance: balance,
      max: feeValue == null ? null : swapMaxIn(spendable, feeValue),
      feeFailed: fee.hasError ? SwapFeeFailedRow(onRetry: () => ref.invalidate(swapDepositFeeProvider(key))) : null,
    );
  }

  /// Picks a side's token. QTC heads the list: picking it for the other side
  /// moves QTC there, as does picking a foreign token for QTC's side.
  Future<void> _pickToken(SwapToken tapped) async {
    final service = ref.read(swapServiceProvider);
    final token = await showTokenPickerSheet(
      context,
      loadTokens: service.getFromTokens,
      paying: tapped.isQuantus == _swapOut,
    );
    if (token == null || !mounted || token == tapped) return;
    if (!token.isQuantus) {
      setState(() {
        if (token.network != _foreign?.network) _address = null;
        _foreign = token;
        _edits++;
      });
    }
    if (token.isQuantus != tapped.isQuantus) _setDirection(swapOut: !_swapOut);
  }

  /// Asks for the external address on [foreign]'s network, then reviews the
  /// swap when an amount is typed; otherwise the address waits on the form.
  Future<void> _addAddress(SwapToken from, SwapToken to, SwapToken foreign) async {
    final address = await showSwapAddressSheet(
      context,
      token: foreign,
      role: _swapOut ? SwapAddressRole.recipient : SwapAddressRole.refund,
    );
    if (address == null || !mounted) return;
    setState(() {
      _address = address;
      _edits++;
    });
    final (amountIn, amountOut) = _amounts(from, to);
    if (amountIn > BigInt.zero && amountOut > BigInt.zero) await _review(from, to, address);
  }

  /// Quotes with the service of the moment, so a config change since the form
  /// was built is seen: the service then refuses the stale QTC token. Shows
  /// the quote's terms. One quote is out at a time, the form takes no taps
  /// meanwhile, and a quote the form was edited past opens nothing.
  Future<void> _review(SwapToken from, SwapToken to, String address) async {
    if (_quoting) return;
    final account = widget.account;
    if (!account.signsLocally) {
      throw StateError('Swaps need a transparent account, ${account.name} is ${account.accountType.name}');
    }
    final own = ref.read(swapPreflightProvider)?.address ?? account.accountId;
    final (amountIn, amountOut) = _amounts(from, to);
    final edits = _edits;
    setState(() => _quoting = true);
    try {
      final quote = await ref
          .read(swapServiceProvider)
          .getQuote(
            from: from,
            to: to,
            amount: _exactOutput ? amountOut : amountIn,
            swapType: _exactOutput ? SwapType.exactOutput : SwapType.exactInput,
            refundAddress: _swapOut ? own : address,
            recipient: _swapOut ? address : own,
            slippageBps: ref.read(swapSlippageBpsProvider),
          );
      if (!mounted || edits != _edits) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewSwapScreen(account: account, quote: quote),
        ),
      );
    } catch (e) {
      quantusPrint('Swap quote failed: $e');
      if (!mounted) return;
      final l10n = ref.read(l10nProvider);
      context.showErrorToaster(message: l10n.swapQuoteError(describeSwapError(l10n, e)));
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(swapServiceProvider, (_, _) => _loadTokens());
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final foreign = _foreign;
    final quantus = _quantus;
    final available = ref.watch(remoteConfigProvider.select((c) => c.swapAvailable));
    final ready = available && foreign != null && quantus != null;
    final funds = _funds();

    return ScaffoldBase(
      appBar: V2AppBar(
        title: l10n.swapTitle,
        slotWidth: NearIntentsAttribution.width,
        trailing: const NearIntentsAttribution(),
      ),
      mainContent: ready
          ? _form(l10n, colors, text, _swapOut ? quantus : foreign, _swapOut ? foreign : quantus, funds)
          : _unavailable(l10n, colors, text, disabled: !available),
      bottomContent: ready
          ? _cta(l10n, colors, text, _swapOut ? quantus : foreign, _swapOut ? foreign : quantus, foreign, funds)
          : null,
    );
  }

  /// In place of the form: "Swap disabled" where swaps are [disabled] for this
  /// location or while 1Click does not list QTC with a price, saying nothing
  /// about why or when; an unreachable 1Click names itself and offers a retry.
  Widget _unavailable(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, {required bool disabled}) {
    final unreachable = _loadFailed && !disabled;
    if (_loadingTokens && !disabled) return const Center(child: Loader());
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderHairline),
              ),
              child: QuantusIcon(QuantusIcons.swapVertical, size: 28, color: colors.textMuted),
            ),
            const SizedBox(height: 24),
            Text(
              unreachable ? l10n.swapUnavailableTitle : l10n.swapDisabledTitle,
              style: text.titleScreen.copyWith(color: colors.textContent),
            ),
            if (unreachable) ...[
              const SizedBox(height: 8),
              Text(
                l10n.swapUnavailableUnreachable,
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _loadTokens(forceRefresh: true),
                child: Text(l10n.commonTryAgain, style: text.body.copyWith(color: colors.accentFlare)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The account can pay up to the most it can put in, or its whole balance
  /// until the fee is known; nothing is checked when the other side pays.
  /// While the amount is typed and that most is known, chips above the
  /// button type a share of it.
  Widget _cta(
    AppLocalizations l10n,
    AppColorsV3 colors,
    AppTextThemeV3 text,
    SwapToken from,
    SwapToken to,
    SwapToken foreign,
    _Funds? funds,
  ) {
    final max = funds?.max;
    final canPay = max ?? funds?.balance.value;
    final (amountIn, amountOut) = _amounts(from, to);
    final insufficient = canPay != null && amountIn > canPay;
    final address = _address;
    return ScaffoldBaseBottomContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (max != null && _amountFocus.hasFocus) ...[
            Row(
              children: [
                for (final share in _chipShares) ...[
                  Expanded(
                    child: _chip(
                      colors,
                      text,
                      label: l10n.commonPercent('$share'),
                      onTap: () => _setAmount(max * BigInt.from(share) ~/ BigInt.from(100), from),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _chip(colors, text, label: l10n.sendInputAmountMax, onTap: () => _setAmount(max, from)),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          QuantusButton.simple(
            label: insufficient
                ? l10n.sendLogicInsufficientBalance
                : address != null
                ? l10n.swapReviewTitle
                : _swapOut
                ? l10n.swapAddRecipientAddress
                : l10n.swapAddRefundAddress,
            onTap: address == null ? () => _addAddress(from, to, foreign) : () => _review(from, to, address),
            isLoading: _quoting,
            isDisabled: insufficient || address != null && (amountIn == BigInt.zero || amountOut == BigInt.zero),
          ),
        ],
      ),
    );
  }

  Widget _chip(AppColorsV3 colors, AppTextThemeV3 text, {required String label, required VoidCallback onTap}) {
    return QuantusButton.simple(
      label: label,
      variant: ButtonVariant.staged,
      padding: const EdgeInsets.symmetric(vertical: 10),
      textStyle: text.caption.copyWith(color: colors.textContent),
      onTap: onTap,
    );
  }

  Widget _form(
    AppLocalizations l10n,
    AppColorsV3 colors,
    AppTextThemeV3 text,
    SwapToken from,
    SwapToken to,
    _Funds? funds,
  ) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final feeFailed = funds?.feeFailed;
    final (amountIn, amountOut) = _amounts(from, to);
    final quantus = from.isQuantus ? from : to;
    final foreign = from.isQuantus ? to : from;
    final oneQuantus = BigInt.from(10).pow(quantus.decimals);
    final priced = from.usdPrice > 0 && to.usdPrice > 0;
    final wallet = widget.account.name;
    final external = l10n.swapExternalWallet;
    final standIn = ref.watch(swapPreflightProvider) == null ? null : (from.isQuantus ? from : to);

    return AbsorbPointer(
      absorbing: _quoting,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            if (standIn != null) ...[
              QuantusBanner(
                tone: BannerTone.sand,
                message: l10n.swapPreflightBanner(standIn.symbol, standIn.networkName),
              ),
              const SizedBox(height: 16),
            ],
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
                        amount: _exactOutput
                            ? _estimateBox(colors, text, fmt, from, amountIn, onTap: () => _typeOtherSide(from, to))
                            : _amountField(text, from),
                        caret: true,
                        onTypeOtherSide: _exactOutput ? null : () => _typeOtherSide(from, to),
                        aside: funds == null ? null : _balanceRow(l10n, colors, text, fmt, from, funds),
                      ),
                      Container(height: 4, color: colors.bgVoid),
                      _section(
                        colors,
                        text,
                        label: l10n.swapTo,
                        owner: _swapOut ? external : wallet,
                        token: to,
                        usd: swapUsdValue(amountOut, to),
                        amount: _exactOutput
                            ? _amountField(text, to)
                            : _estimateBox(colors, text, fmt, to, amountOut, onTap: () => _typeOtherSide(from, to)),
                        caret: false,
                        onTypeOtherSide: _exactOutput ? () => _typeOtherSide(from, to) : null,
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
            if (feeFailed != null) ...[const SizedBox(height: 12), feeFailed],
            const SizedBox(height: 12),
            Row(
              children: [
                if (priced)
                  Expanded(
                    child: Text(
                      l10n.swapRateLabel(
                        quantus.symbol,
                        fmt.formatAmount(swapEstimateOut(oneQuantus, quantus, foreign), decimals: foreign.decimals),
                        foreign.symbol,
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
                      _dot(colors, _slippageIconAsset),
                    ],
                  ),
                ),
              ],
            ),
            if (_address case final address?) ...[
              const SizedBox(height: 20),
              _addressRow(l10n, colors, text, address, onTap: () => _addAddress(from, to, foreign)),
            ],
          ],
        ),
      ),
    );
  }

  /// The external address the swap refunds to or pays out at; a tap changes it.
  Widget _addressRow(
    AppLocalizations l10n,
    AppColorsV3 colors,
    AppTextThemeV3 text,
    String address, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: context.radiusV3.mdBorder,
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Text(
              (_swapOut ? l10n.swapReviewRecipient : l10n.swapRefundTo).toUpperCase(),
              style: text.labelData.copyWith(color: colors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      AddressFormattingService.formatAddress(address),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyEmphasis.copyWith(color: colors.textContent),
                    ),
                  ),
                  const SizedBox(width: 4),
                  QuantusIcon(QuantusIcons.chevronRight, color: colors.textContent, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The most the account can put in once the deposit's fee is known; a tap
  /// types it.
  Widget _balanceRow(
    AppLocalizations l10n,
    AppColorsV3 colors,
    AppTextThemeV3 text,
    NumberFormattingService fmt,
    SwapToken from,
    _Funds funds,
  ) {
    final max = funds.max;
    final shown = max != null
        ? formatSwapAmount(l10n, fmt, max, from)
        : funds.balance.hasError
        ? '—'
        : '…';
    return GestureDetector(
      onTap: max == null ? null : () => _setAmount(max, from),
      behavior: HitTestBehavior.opaque,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${l10n.sendInputAmountMax} ',
              style: text.body.copyWith(color: colors.textMuted),
            ),
            TextSpan(
              text: shown,
              style: text.body.copyWith(color: colors.textContent),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// [aside] sits left of the USD value, under the amount. The side typed on
  /// carries a dot by its USD value that [onTypeOtherSide] moves typing away.
  Widget _section(
    AppColorsV3 colors,
    AppTextThemeV3 text, {
    required String label,
    required String owner,
    required SwapToken token,
    required double usd,
    required Widget amount,
    required bool caret,
    VoidCallback? onTypeOtherSide,
    Widget? aside,
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _tokenPill(colors, text, token, caret: caret),
                ),
              ),
              const SizedBox(width: 12),
              amount,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: aside ?? const SizedBox.shrink()),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onTypeOtherSide != null) ...[
                    GestureDetector(onTap: onTypeOtherSide, child: _dot(colors, _directionIconAsset)),
                    const SizedBox(width: 8),
                  ],
                  Text('\$${usd.toStringAsFixed(2)}', style: text.body.copyWith(color: colors.textMuted)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The side's token; a [caret] marks the side whose token is picked.
  Widget _tokenPill(AppColorsV3 colors, AppTextThemeV3 text, SwapToken token, {required bool caret}) {
    return GestureDetector(
      onTap: () => _pickToken(token),
      child: GlassButtonBase(
        buttonHeight: _rowHeight,
        borderRadius: context.radiusV3.pillBorder,
        padding: const EdgeInsets.only(left: 6, right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TokenIcon(token: token),
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
            if (caret) ...[
              const SizedBox(width: 11),
              QuantusIcon(QuantusIcons.caretDown, color: colors.textMuted, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  /// 20pt outlined dot holding a 10pt [asset], as next to Slippage.
  Widget _dot(AppColorsV3 colors, String asset) {
    return Container(
      width: 20,
      height: 20,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.bgVoid,
        shape: BoxShape.circle,
        border: Border.all(color: colors.borderHairline),
      ),
      child: SvgPicture.asset(asset, colorFilter: ColorFilter.mode(colors.textContent, BlendMode.srcIn)),
    );
  }

  /// The side not typed on: its amount at listed prices; a tap types there.
  Widget _estimateBox(
    AppColorsV3 colors,
    AppTextThemeV3 text,
    NumberFormattingService fmt,
    SwapToken token,
    BigInt estimate, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AmountBox(
        width: _amountBoxWidth,
        height: _rowHeight,
        child: Text(
          fmt.formatAmount(estimate, decimals: token.decimals),
          style: text.amountInline.copyWith(color: estimate > BigInt.zero ? colors.textContent : colors.textMuted2),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _amountField(AppTextThemeV3 text, SwapToken token) {
    return AmountBox(
      width: _amountBoxWidth,
      height: _rowHeight,
      child: AmountBoxField(
        controller: _amountController,
        focusNode: _amountFocus,
        style: text.amountInline,
        maxDecimalPlaces: token.decimals,
      ),
    );
  }
}
