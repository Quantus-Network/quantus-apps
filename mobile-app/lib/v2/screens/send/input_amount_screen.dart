import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/send/review_send_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_screen_logic.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/shared/utils/amount_input_logic.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class InputAmountScreen extends ConsumerStatefulWidget {
  final SendStrategy strategy;
  final String recipientAddress;
  final String? recipientChecksum;
  final String? initialAmount;
  final bool isPayMode;

  const InputAmountScreen({
    super.key,
    required this.strategy,
    required this.recipientAddress,
    this.recipientChecksum,
    this.initialAmount,
    this.isPayMode = false,
  });

  @override
  ConsumerState<InputAmountScreen> createState() => _InputAmountScreenState();
}

class _InputAmountScreenState extends ConsumerState<InputAmountScreen> {
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  final _checksumService = HumanReadableChecksumService();

  String? _recipientChecksum;
  BigInt _amount = BigInt.zero;

  String get _recipient => widget.recipientAddress.trim();

  ProviderListenable<AsyncValue<SendFee>> _feeProvider(BigInt amount) =>
      widget.strategy.feeProvider(recipient: _recipient, amount: amount);

  AmountInputLogic get _amountInputLogic => AmountInputLogic(
    exchangeRateService: ref.read(exchangeRateServiceProvider),
    selectedFiat: ref.read(selectedFiatCurrencyProvider),
    localeConfig: ref.read(localeNumberConfigProvider),
    formattingService: ref.read(numberFormattingServiceProvider),
  );

  @override
  void initState() {
    super.initState();
    assert(widget.recipientAddress.trim().isNotEmpty, 'InputAmountScreen requires a recipient');
    if (widget.initialAmount != null && widget.initialAmount!.isNotEmpty) {
      final formattingService = ref.read(numberFormattingServiceProvider);
      final token = widget.isPayMode
          ? formattingService.parseWireAmount(widget.initialAmount!) ?? BigInt.zero
          : _amountInputLogic.parseTokenAmount(widget.initialAmount!);
      if (token > BigInt.zero) {
        _amount = token;
        _amountController.text = _amountInputLogic.formatTokenAmount(token);
      }
    }
    _recipientChecksum = widget.recipientChecksum;
    _checksumService.getHumanReadableName(widget.recipientAddress.trim()).then((name) {
      if (!mounted) return;
      setState(() => _recipientChecksum = name);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _onAmountChanged(String _) {
    HapticFeedback.mediumImpact();

    final isFlipped = widget.isPayMode ? false : ref.read(isCurrencyFlippedProvider);
    try {
      setState(() => _amount = _amountInputLogic.onAmountChanged(value: _amountController.text, isFlipped: isFlipped));
    } on InvalidNumberInputException catch (e, stack) {
      quantusPrint('Amount parse failed: $e\n$stack');
      final l10n = ref.read(l10nProvider);
      context.showErrorToaster(message: l10n.sendInputAmountInvalidAmount);
      return;
    }
  }

  /// Converts a token amount [BigInt] to a fiat input string using the current
  /// exchange rate and selected fiat currency, formatted for the user's locale.
  void _setMax() {
    final spendable = ref.read(widget.strategy.spendableBalanceProvider).value ?? BigInt.zero;
    final feeAtMax = ref.read(_feeProvider(spendable)).value;
    final max = SendScreenLogic.calculateMaxSendableAmount(
      balance: spendable,
      networkFee: widget.strategy.feeChargedToBalance(feeAtMax),
    );
    final isFlipped = ref.read(isCurrencyFlippedProvider);
    _amountController.text = isFlipped
        ? _amountInputLogic.tokenToFiatString(max)
        : _amountInputLogic.formatTokenAmount(max);
    setState(() => _amount = max);
  }

  Future<void> _toggleFlip() async {
    final wasFlipped = ref.read(isCurrencyFlippedProvider);
    await ref.read(isCurrencyFlippedProvider.notifier).toggle();

    final result = _amountInputLogic.getToggledInput(wasFlipped: wasFlipped, currentAmount: _amount);

    setState(() {
      _amountController.text = result.text;
      _amount = result.amount;
    });
  }

  void _openReview() {
    final fee = ref.read(_feeProvider(_amount)).value;
    final l10n = ref.read(l10nProvider);
    if (_recipientChecksum == null) {
      context.showErrorToaster(message: l10n.sendInputAmountChecksumRequired);
      return;
    }
    if (fee == null) {
      context.showErrorToaster(message: widget.strategy.strings(l10n).feeFetchFailedMessage);
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSendScreen(
          strategy: widget.strategy,
          recipientAddress: widget.recipientAddress,
          amount: _amount,
          fee: fee,
          recipientChecksum: _recipientChecksum!,
          isPayMode: widget.isPayMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final strings = widget.strategy.strings(l10n);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final balance = ref.watch(widget.strategy.spendableBalanceProvider);
    final displayBalance = ref.watch(widget.strategy.displayBalanceProvider);
    final sourceId = widget.strategy.sourceAccountId(ref) ?? '';
    final recipient = _recipient;
    final formattingService = ref.read(numberFormattingServiceProvider);
    final feeAsync = ref.watch(_feeProvider(_amount));
    final fee = feeAsync.value;

    final amountStatus = SendScreenLogic.getAmountStatus(
      _amount,
      balance.value ?? BigInt.zero,
      widget.strategy.feeChargedToBalance(fee),
    );
    final affordabilityError = fee == null ? null : widget.strategy.affordabilityError(ref, fee, l10n);
    final btnDisabled =
        fee == null ||
        _recipientChecksum == null ||
        !balance.hasValue ||
        widget.strategy.extraBalancesLoading(ref) ||
        affordabilityError != null ||
        SendScreenLogic.isButtonDisabled(
          hasAddressError: false,
          amountStatus: amountStatus,
          recipientText: recipient,
          activeAccountId: sourceId,
        );
    final btnText =
        affordabilityError ??
        (amountStatus == AmountStatus.valid
            ? strings.reviewButtonLabel
            : SendScreenLogic.getButtonText(
                l10n: l10n,
                hasAddressError: false,
                amountStatus: amountStatus,
                recipientText: recipient,
                amount: _amount,
                activeAccountId: sourceId,
                formattingService: formattingService,
              ));

    return ScaffoldBase(
      key: const Key(E2EKeys.sendInputAmountScreen),
      appBar: V2AppBar(title: widget.isPayMode ? l10n.sendPayTitle : strings.flowTitle),
      mainContent: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            // Fill the viewport so the amount block centres in whatever the
            // keyboard leaves, and grow past it — scrolling — once the recipient
            // card and the amount need more room than that, as at large text sizes.
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _recipientCard(colors, text, strings),
                  Expanded(child: _amountCenter(colors, text)),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomContent: _bottomSection(colors, text, l10n, strings, btnText, displayBalance, feeAsync, btnDisabled),
    );
  }

  Widget _recipientCard(AppColorsV3 colors, AppTextThemeV3 text, SendStrings strings) {
    final addr = widget.recipientAddress.trim();
    final shortAddr = AddressFormattingService.formatAddress(addr);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.amountRecipientCardLabel, style: text.labelData.copyWith(color: colors.textMuted)),
                const SizedBox(height: 16),
                if (_recipientChecksum != null) ...[
                  Text(
                    _recipientChecksum!,
                    style: text.body.copyWith(color: colors.semanticLilac),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(shortAddr, style: text.dataAddress.copyWith(color: colors.textContent)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: colors.bgVoid,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.borderHairline),
                ),
                child: Icon(Icons.edit_outlined, size: 18, color: colors.textContent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountCenter(AppColorsV3 colors, AppTextThemeV3 text) {
    final isPayMode = widget.isPayMode;
    final isFlipped = isPayMode ? false : ref.watch(isCurrencyFlippedProvider);
    final selectedFiat = ref.watch(selectedFiatCurrencyProvider);
    final localeConfig = ref.watch(localeNumberConfigProvider);
    final display = ref.watch(txAmountDisplayProvider)(
      _amount,
      withSignPrefix: false,
      tokenDecimals: 4,
      isSend: true,
      withTokenSymbol: false,
    );

    final amountColor = _amount == BigInt.zero ? colors.textMuted2 : colors.textContent;
    final amountStyle = text.displayCharge.copyWith(color: amountColor);
    final symbolStyle = text.amountHero.copyWith(color: colors.textContent);
    final isPrefixFiat = isFlipped && selectedFiat.symbolPosition == SymbolPosition.prefix;

    final maxDecimals = isFlipped ? selectedFiat.decimals : null;
    final inputField = IntrinsicWidth(
      child: TextField(
        key: const Key(E2EKeys.sendAmountField),
        controller: _amountController,
        focusNode: _amountFocus,
        onChanged: _onAmountChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: isPrefixFiat ? TextAlign.left : TextAlign.right,
        inputFormatters: [DecimalInputFilter(localeConfig: localeConfig, maxDecimalPlaces: maxDecimals)],
        style: amountStyle,
        decoration: InputDecoration(
          isDense: true,
          hintText: '0',
          hintStyle: text.displayCharge.copyWith(color: colors.textMuted2),
        ),
      ),
    );

    final symbolWidget = Text(isFlipped ? selectedFiat.symbol : AppConstants.tokenSymbol, style: symbolStyle);

    // For prefix fiat currencies (e.g. $, Rp) place symbol before the field;
    // for suffix currencies and the token symbol keep it after.
    final List<Widget> primaryRowChildren = isPrefixFiat
        ? [symbolWidget, const SizedBox(width: 8), inputField]
        : [inputField, const SizedBox(width: 8), symbolWidget];

    // Scales down rather than clipping when the keyboard leaves little room,
    // or when a long amount would overflow horizontally.
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: primaryRowChildren,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('≈ ${display.secondaryAmount}', style: text.body.copyWith(color: colors.textMuted)),
                if (!isPayMode) ...[
                  const SizedBox(width: 8),
                  QuantusIconButton.circular(
                    icon: Icons.swap_vert,
                    onTap: _toggleFlip,
                    isActive: display.isFlipped,
                    size: IconButtonSize.small,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeValue(
    AppColorsV3 colors,
    AppTextThemeV3 text,
    AppLocalizations l10n,
    SendStrings strings,
    NumberFormattingService fmt,
    AsyncValue<SendFee> feeAsync,
  ) {
    return feeAsync.when(
      data: (fee) => Text(
        l10n.commonAmountBalance(fmt.formatBalance(fee.displayFee, smartDecimals: 5), AppConstants.tokenSymbol),
        style: text.body.copyWith(color: colors.textMuted),
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            strings.feeFetchFailedMessage,
            style: text.body.copyWith(color: colors.semanticEmber),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          IntrinsicWidth(
            child: QuantusButton.simple(
              label: l10n.homeActivityRetry,
              onTap: () => widget.strategy.retryFee(ref, recipient: _recipient, amount: _amount),
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              variant: ButtonVariant.ghost,
              textStyle: text.body.copyWith(
                color: colors.accentFlare,
                decoration: TextDecoration.underline,
                decorationColor: colors.accentFlare,
              ),
            ),
          ),
        ],
      ),
      loading: () => const Align(alignment: Alignment.centerRight, child: Loader()),
    );
  }

  Widget _bottomSection(
    AppColorsV3 colors,
    AppTextThemeV3 text,
    AppLocalizations l10n,
    SendStrings strings,
    String btnText,
    AsyncValue<BigInt> balance,
    AsyncValue<SendFee> feeAsync,
    bool btnDisabled,
  ) {
    final formattingService = ref.read(numberFormattingServiceProvider);
    final feePayerProvider = widget.strategy.feePayerBalanceProvider;
    final feePayerLabel = widget.strategy.feePayerBalanceLabel(l10n);
    final mutedBody = text.body.copyWith(color: colors.textMuted);

    return ScaffoldBaseBottomContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.sendInputAmountAvailableBalance, style: mutedBody),
                        const SizedBox(height: 4),
                        balance.when(
                          data: (b) => Text(
                            l10n.commonAmountBalance(formattingService.formatBalance(b), AppConstants.tokenSymbol),
                            style: mutedBody,
                          ),
                          loading: () => Text('...', style: mutedBody),
                          error: (_, _) => Text('—', style: mutedBody),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(strings.feeLabel, style: mutedBody),
                        const SizedBox(height: 4),
                        _feeValue(colors, text, l10n, strings, formattingService, feeAsync),
                      ],
                    ),
                  ),
                ],
              ),
              if (feePayerProvider != null && feePayerLabel != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_feePayerBalance(colors, text, l10n, feePayerLabel, feePayerProvider, formattingService)],
                ),
              ],
              const SizedBox(height: 4),
              IntrinsicWidth(
                child: QuantusButton.simple(
                  label: l10n.sendInputAmountMax,
                  onTap: _setMax,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  variant: ButtonVariant.ghost,
                  textStyle: text.body.copyWith(
                    color: colors.accentFlare,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.accentFlare,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          QuantusButton.simple(
            key: const Key(E2EKeys.sendReviewButton),
            label: btnText,
            variant: ButtonVariant.primary,
            isDisabled: btnDisabled,
            onTap: _openReview,
          ),
        ],
      ),
    );
  }

  Widget _feePayerBalance(
    AppColorsV3 colors,
    AppTextThemeV3 text,
    AppLocalizations l10n,
    String label,
    ProviderListenable<AsyncValue<BigInt>> provider,
    NumberFormattingService fmt,
  ) {
    final balanceAsync = ref.watch(provider);
    final style = text.body.copyWith(color: colors.textMuted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: style),
        balanceAsync.when(
          data: (b) => Text(l10n.commonAmountBalance(fmt.formatBalance(b), AppConstants.tokenSymbol), style: style),
          loading: () => Text('...', style: style),
          error: (_, _) => Text('—', style: style),
        ),
      ],
    );
  }
}
