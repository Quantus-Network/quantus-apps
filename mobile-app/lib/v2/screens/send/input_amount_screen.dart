import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/send/review_send_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_screen_logic.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/amount_input_logic.dart';
import 'package:resonance_network_wallet/shared/utils/debouncer.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';

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
  final _scrollController = ScrollController();
  final _amountCenterKey = GlobalKey();
  final _checksumService = HumanReadableChecksumService();

  final _feeDebouncer = Debouncer(delay: const Duration(milliseconds: 500));

  String? _recipientChecksum;
  BigInt _amount = BigInt.zero;
  SendFee? _fee;
  bool _isFetchingFee = false;
  bool _hasFee = false;
  bool _feeFetchFailed = false;
  // Each request has a counter value, so old responses can be ignored
  int _fetchFeeCounter = 0;

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
    _amountFocus.addListener(_onAmountFocusChanged);
    if (widget.initialAmount != null && widget.initialAmount!.isNotEmpty) {
      final formattingService = ref.read(numberFormattingServiceProvider);
      final planck = widget.isPayMode
          ? formattingService.parseWireAmount(widget.initialAmount!) ?? BigInt.zero
          : _amountInputLogic.parseQuanAmount(widget.initialAmount!);
      if (planck > BigInt.zero) {
        _amount = planck;
        _amountController.text = _amountInputLogic.formatQuanAmount(planck);
      }
    }
    if (widget.recipientChecksum != null) {
      _recipientChecksum = widget.recipientChecksum;
    } else {
      _checksumService.getHumanReadableName(widget.recipientAddress.trim()).then((name) {
        if (mounted) setState(() => _recipientChecksum = name);
      });
    }

    _refreshFee();
  }

  @override
  void dispose() {
    _feeDebouncer.cancel();
    _amountController.dispose();
    _amountFocus.removeListener(_onAmountFocusChanged);
    _amountFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onAmountFocusChanged() {
    if (!_amountFocus.hasFocus) return;
    // Wait for the keyboard animation to finish before scrolling so that the
    // viewport has already shrunk and ensureVisible can compute the correct offset.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final ctx = _amountCenterKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          // ignore: use_build_context_synchronously
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onAmountChanged(String _) {
    HapticFeedback.mediumImpact();

    final isFlipped = widget.isPayMode ? false : ref.read(isCurrencyFlippedProvider);
    try {
      setState(() => _amount = _amountInputLogic.onAmountChanged(value: _amountController.text, isFlipped: isFlipped));
    } on InvalidNumberInputException catch (e, stack) {
      debugPrint('Amount parse failed: $e\n$stack');
      final l10n = ref.read(l10nProvider);
      context.showErrorToaster(message: l10n.sendInputAmountInvalidAmount);
      return;
    }
    _feeDebouncer.run(_refreshFee);
  }

  void _refreshFee() {
    final counter = ++_fetchFeeCounter;
    final showLoader = !_hasFee || _feeFetchFailed;
    setState(() {
      _isFetchingFee = showLoader;
      if (showLoader) _feeFetchFailed = false;
    });
    _fetchFee(counter);
  }

  Future<void> _fetchFee(int counter) async {
    try {
      final fee = await widget.strategy.estimateFee(ref, recipient: widget.recipientAddress.trim(), amount: _amount);
      if (!mounted || counter != _fetchFeeCounter) return;
      setState(() {
        _fee = fee;
        _hasFee = true;
        _feeFetchFailed = false;
        _isFetchingFee = false;
      });
    } catch (e, st) {
      debugPrint('Fee fetch error: $e\n$st');
      if (!mounted || counter != _fetchFeeCounter) return;
      setState(() {
        _fee = null;
        _hasFee = false;
        _feeFetchFailed = true;
        _isFetchingFee = false;
      });
    }
  }

  void _retryFeeFetch() {
    _feeDebouncer.cancel();
    _refreshFee();
  }

  /// Converts a raw QUAN [BigInt] to a fiat input string using the current
  /// exchange rate and selected fiat currency, formatted for the user's locale.
  void _setMax() {
    final spendable = ref.read(widget.strategy.spendableBalanceProvider).value ?? BigInt.zero;
    final max = SendScreenLogic.calculateMaxSendableAmount(
      balance: spendable,
      networkFee: widget.strategy.feeChargedToBalance(_fee),
    );
    final isFlipped = ref.read(isCurrencyFlippedProvider);
    _amountController.text = isFlipped
        ? _amountInputLogic.quanToFiatString(max)
        : _amountInputLogic.formatQuanAmount(max);
    setState(() => _amount = max);
    _refreshFee();
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
    final fee = _fee;
    if (_recipientChecksum == null || fee == null) {
      context.showErrorToaster(message: ref.read(l10nProvider).sendInputAmountChecksumRequired);
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
    final colors = context.colors;
    final text = context.themeText;
    final balance = ref.watch(widget.strategy.spendableBalanceProvider);
    final displayBalance = ref.watch(widget.strategy.displayBalanceProvider);
    final sourceId = widget.strategy.sourceAccountId(ref) ?? '';
    final recipient = widget.recipientAddress.trim();
    final formattingService = ref.read(numberFormattingServiceProvider);
    final fee = _fee;

    final amountStatus = SendScreenLogic.getAmountStatus(
      _amount,
      balance.value ?? BigInt.zero,
      widget.strategy.feeChargedToBalance(fee),
    );
    final affordabilityError = fee == null ? null : widget.strategy.affordabilityError(ref, fee, l10n);
    final btnDisabled =
        !_hasFee ||
        _feeFetchFailed ||
        _recipientChecksum == null ||
        balance.isLoading ||
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
          controller: _scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _recipientCard(colors, text, strings),
                const SizedBox(height: 32),
                _amountCenter(colors, text),
                const SizedBox(height: 32),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
      bottomContent: _bottomSection(colors, text, l10n, strings, btnText, displayBalance, btnDisabled),
    );
  }

  Widget _recipientCard(AppColorsV2 colors, AppTextTheme text, SendStrings strings) {
    final addr = widget.recipientAddress.trim();
    final shortAddr = AddressFormattingService.formatAddress(addr);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.amountRecipientCardLabel,
                  style: context.themeText.receiveLabel?.copyWith(color: colors.textLabel),
                ),
                const SizedBox(height: 16),
                if (_recipientChecksum != null) ...[
                  Text(
                    _recipientChecksum!,
                    style: text.smallParagraph?.copyWith(color: colors.checksum, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  shortAddr,
                  style: text.detail?.copyWith(
                    color: colors.textMuted,
                    fontFamily: AppTextTheme.fontFamilySecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: colors.background,
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
                  border: Border.all(color: colors.borderButton),
                ),
                child: Icon(Icons.edit_outlined, size: 18, color: colors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountCenter(AppColorsV2 colors, AppTextTheme text) {
    final isPayMode = widget.isPayMode;
    final isFlipped = isPayMode ? false : ref.watch(isCurrencyFlippedProvider);
    final selectedFiat = ref.watch(selectedFiatCurrencyProvider);
    final localeConfig = ref.watch(localeNumberConfigProvider);
    final display = ref.watch(txAmountDisplayProvider)(
      _amount,
      withSignPrefix: false,
      quanDecimals: 4,
      isSend: true,
      withQuanSymbol: false,
    );

    final symbolStyle = text.transactionDetailAmountSymbol?.copyWith(color: colors.textPrimary);
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
        style: text.transactionDetailAmountPrimary?.copyWith(
          color: _amount == BigInt.zero ? colors.textTertiary : colors.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: '0',
          hintStyle: text.transactionDetailAmountPrimary?.copyWith(color: colors.textTertiary),
        ),
      ),
    );

    final symbolWidget = Text(isFlipped ? selectedFiat.symbol : AppConstants.tokenSymbol, style: symbolStyle);

    // For prefix fiat currencies (e.g. $, Rp) place symbol before the field;
    // for suffix currencies and QUAN keep it after.
    final List<Widget> primaryRowChildren = isPrefixFiat
        ? [symbolWidget, const SizedBox(width: 8), inputField]
        : [inputField, const SizedBox(width: 8), symbolWidget];

    return Center(
      key: _amountCenterKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: primaryRowChildren,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '≈ ${display.secondaryAmount}',
                style: text.paragraph?.copyWith(
                  color: colors.textTertiary,
                  fontFamily: AppTextTheme.fontFamilySecondary,
                ),
              ),
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
    );
  }

  Widget _feeValue(
    AppColorsV2 colors,
    AppTextTheme text,
    AppLocalizations l10n,
    SendStrings strings,
    NumberFormattingService fmt,
  ) {
    if (_isFetchingFee) {
      return const Align(alignment: Alignment.centerRight, child: Loader());
    }
    if (_feeFetchFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            strings.feeFetchFailedMessage,
            style: text.smallParagraph?.copyWith(color: colors.error),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          IntrinsicWidth(
            child: QuantusButton.simple(
              label: l10n.homeActivityRetry,
              onTap: _retryFeeFetch,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              variant: ButtonVariant.transparent,
              textStyle: text.smallParagraph?.copyWith(
                color: colors.accentOrange,
                decoration: TextDecoration.underline,
                decorationColor: colors.accentOrange,
              ),
            ),
          ),
        ],
      );
    }
    final fee = _fee;
    if (_hasFee && fee != null) {
      return Text(
        l10n.commonAmountBalance(fmt.formatBalance(fee.displayFee, smartDecimals: 5), AppConstants.tokenSymbol),
        style: text.smallParagraph?.copyWith(color: colors.textTertiary),
      );
    }
    return const Align(alignment: Alignment.centerRight, child: Loader());
  }

  Widget _bottomSection(
    AppColorsV2 colors,
    AppTextTheme text,
    AppLocalizations l10n,
    SendStrings strings,
    String btnText,
    AsyncValue<BigInt> balance,
    bool btnDisabled,
  ) {
    final formattingService = ref.read(numberFormattingServiceProvider);
    final feePayerProvider = widget.strategy.feePayerBalanceProvider;
    final feePayerLabel = widget.strategy.feePayerBalanceLabel(l10n);

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
                        Text(
                          l10n.sendInputAmountAvailableBalance,
                          style: text.smallParagraph?.copyWith(color: colors.textTertiary),
                        ),
                        const SizedBox(height: 4),
                        balance.when(
                          data: (b) => Text(
                            l10n.commonAmountBalance(formattingService.formatBalance(b), AppConstants.tokenSymbol),
                            style: text.smallParagraph?.copyWith(color: colors.textTertiary),
                          ),
                          loading: () => Text('...', style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
                          error: (_, _) => Text('—', style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(strings.feeLabel, style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
                        const SizedBox(height: 4),
                        _feeValue(colors, text, l10n, strings, formattingService),
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
                  variant: ButtonVariant.transparent,
                  textStyle: text.smallParagraph?.copyWith(
                    color: colors.accentOrange,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.accentOrange,
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
    AppColorsV2 colors,
    AppTextTheme text,
    AppLocalizations l10n,
    String label,
    ProviderListenable<AsyncValue<BigInt>> provider,
    NumberFormattingService fmt,
  ) {
    final balanceAsync = ref.watch(provider);
    final style = text.smallParagraph?.copyWith(color: colors.textTertiary);
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
