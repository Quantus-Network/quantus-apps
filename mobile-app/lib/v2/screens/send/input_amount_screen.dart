import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/send/review_send_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_screen_logic.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/debouncer.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';

class InputAmountScreen extends ConsumerStatefulWidget {
  final String recipientAddress;
  final String? recipientChecksum;
  final String? initialAmount;
  final bool isPayMode;

  const InputAmountScreen({
    super.key,
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
  BigInt _networkFee = BigInt.zero;
  int _blockHeight = 0;
  bool _isFetchingFee = true;
  bool _isUpdatingProgrammatically = false;

  LocaleNumberConfig get _localeConfig => ref.read(localeNumberConfigProvider);

  @override
  void initState() {
    super.initState();
    assert(widget.recipientAddress.trim().isNotEmpty, 'InputAmountScreen requires a recipient');
    _amountController.addListener(_onAmountChanged);
    _amountFocus.addListener(_onAmountFocusChanged);
    if (widget.initialAmount != null) {
      final isFlipped = ref.read(isCurrencyFlippedProvider);
      if (!isFlipped) {
        _amountController.text = widget.initialAmount!;
      } else {
        final formattingService = ref.read(numberFormattingServiceProvider);
        final parsed = formattingService.parseAmount(widget.initialAmount!);
        if (parsed != null && parsed > BigInt.zero) {
          _amount = parsed;
          _isUpdatingProgrammatically = true;
          _amountController.text = _quanToFiatString(parsed);
          _isUpdatingProgrammatically = false;
        }
      }
    }
    if (widget.recipientChecksum != null) {
      _recipientChecksum = widget.recipientChecksum;
    } else {
      _checksumService.getHumanReadableName(widget.recipientAddress.trim()).then((name) {
        if (mounted) setState(() => _recipientChecksum = name);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEstimatedFee();
    });
  }

  @override
  void dispose() {
    _feeDebouncer.cancel();
    _amountController.removeListener(_onAmountChanged);
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

  void _onAmountChanged() {
    if (_isUpdatingProgrammatically) return;
    final isFlipped = ref.read(isCurrencyFlippedProvider);
    if (isFlipped) {
      try {
        final convertedAmount = _fiatStringToQuan(_amountController.text);
        setState(() => _amount = convertedAmount);
      } on InvalidNumberInputException catch (e, stack) {
        debugPrint('Fiat→QUAN parse failed: $e\n$stack');
        context.showErrorToaster(message: 'Please enter a valid amount');
        return;
      }
    } else {
      final formattingService = ref.read(numberFormattingServiceProvider);
      final parsed = formattingService.parseAmount(_amountController.text);
      setState(() => _amount = parsed ?? BigInt.zero);
    }
    if (_amount > BigInt.zero) _feeDebouncer.run(_fetchFee);
  }

  Future<void> _fetchEstimatedFee() async {
    final displayAccount = ref.read(activeAccountProvider).value;
    if (displayAccount is! RegularAccount) return;
    final account = displayAccount.account;
    try {
      final balancesService = ref.read(balancesServiceProvider);
      final formattingService = ref.read(numberFormattingServiceProvider);
      final feeData = await balancesService.getBalanceTransferFee(
        account,
        account.accountId,
        formattingService.parseAmount('1000') ?? BigInt.zero,
      );
      if (!mounted) return;
      setState(() {
        _networkFee = feeData.fee;
        _blockHeight = feeData.blockNumber;
      });
    } catch (e) {
      debugPrint('Estimated fee fetch error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingFee = false);
    }
  }

  Future<void> _fetchFee() async {
    if (_isFetchingFee) return;
    setState(() => _isFetchingFee = true);
    try {
      final displayAccount = ref.read(activeAccountProvider).value;
      if (displayAccount is! RegularAccount) return;
      final balancesService = ref.read(balancesServiceProvider);
      final feeData = await balancesService.getBalanceTransferFee(
        displayAccount.account,
        widget.recipientAddress.trim(),
        _amount,
      );
      if (!mounted) return;
      setState(() {
        _networkFee = feeData.fee;
        _blockHeight = feeData.blockNumber;
      });
    } catch (e) {
      debugPrint('Fee fetch error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingFee = false);
    }
  }

  /// Converts a raw QUAN [BigInt] to a fiat input string using the current
  /// exchange rate and selected fiat currency, formatted for the user's locale.
  String _quanToFiatString(BigInt quanAmount) {
    final xRate = ref.read(exchangeRateServiceProvider);
    final selectedFiat = ref.read(selectedFiatCurrencyProvider);
    final fiatValue = xRate.quanRawToFiat(quanAmount, selectedFiat, AppConstants.decimals);
    final canonical = fiatValue.toStringAsFixed(selectedFiat.decimals);
    return _localeConfig.localize(canonical, addGroupingSeparators: false);
  }

  /// Parses a locale-formatted fiat input string and returns the equivalent
  /// raw QUAN [BigInt] scaled by [AppConstants.decimals].
  ///
  /// Throws [InvalidNumberInputException] when [fiatText] cannot be parsed.
  BigInt _fiatStringToQuan(String fiatText) {
    if (fiatText.isEmpty) return BigInt.zero;
    final fiatDecimal = _localeConfig.parseDecimal(fiatText);
    final xRate = ref.read(exchangeRateServiceProvider);
    final selectedFiat = ref.read(selectedFiatCurrencyProvider);
    return xRate.fiatToQuanRaw(fiatDecimal, selectedFiat, AppConstants.decimals);
  }

  void _setMax() {
    final balance = ref.read(effectiveMaxBalanceProvider).value ?? BigInt.zero;
    final max = SendScreenLogic.calculateMaxSendableAmount(balance: balance, networkFee: _networkFee);
    final isFlipped = ref.read(isCurrencyFlippedProvider);
    final formattingService = ref.read(numberFormattingServiceProvider);
    _isUpdatingProgrammatically = true;
    try {
      _amountController.text = isFlipped
          ? _quanToFiatString(max)
          : formattingService.formatBalance(max, maxDecimals: AppConstants.decimals, addThousandsSeparators: false);
    } finally {
      _isUpdatingProgrammatically = false;
    }
    setState(() => _amount = max);
    if (max > BigInt.zero) _fetchFee();
  }

  Future<void> _toggleFlip() async {
    final wasFlipped = ref.read(isCurrencyFlippedProvider);
    await ref.read(isCurrencyFlippedProvider.notifier).toggle();
    final formattingService = ref.read(numberFormattingServiceProvider);
    _isUpdatingProgrammatically = true;
    try {
      if (!wasFlipped) {
        _amountController.text = _amount == BigInt.zero ? '' : _quanToFiatString(_amount);
      } else {
        _amountController.text = _amount == BigInt.zero
            ? ''
            : formattingService.formatBalance(
                _amount,
                maxDecimals: AppConstants.decimals,
                addThousandsSeparators: false,
              );
      }
    } finally {
      _isUpdatingProgrammatically = false;
    }
  }

  Future<void> _openReview() async {
    if (_recipientChecksum == null) {
      context.showErrorToaster(message: 'Recipient checksum is required');
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSendScreen(
          recipientAddress: widget.recipientAddress,
          amount: _amount,
          networkFee: _networkFee,
          blockHeight: _blockHeight,
          recipientChecksum: _recipientChecksum!,
          isPayMode: widget.isPayMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(activeAccountProvider);
    final colors = context.colors;
    final text = context.themeText;
    final balance = ref.watch(effectiveMaxBalanceProvider);
    final activeId = ref.watch(activeAccountProvider).value?.account.accountId ?? '';
    final recipient = widget.recipientAddress.trim();
    final formattingService = ref.read(numberFormattingServiceProvider);

    final amountStatus = SendScreenLogic.getAmountStatus(_amount, balance.value ?? BigInt.zero, _networkFee);
    final btnDisabled =
        _recipientChecksum == null ||
        SendScreenLogic.isButtonDisabled(
          hasAddressError: false,
          amountStatus: amountStatus,
          recipientText: recipient,
          activeAccountId: activeId,
        );
    final btnText = SendScreenLogic.getButtonText(
      hasAddressError: false,
      amountStatus: amountStatus,
      recipientText: recipient,
      amount: _amount,
      activeAccountId: activeId,
      formattingService: formattingService,
    );

    return ScaffoldBase(
      appBar: V2AppBar(title: widget.isPayMode ? 'Pay' : 'Send'),
      mainContent: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: _scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _recipientCard(colors, text),
                const SizedBox(height: 32),
                _amountCenter(colors, text),
                const SizedBox(height: 32),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
      bottomContent: _bottomSection(colors, text, btnText, balance, btnDisabled),
    );
  }

  Widget _recipientCard(AppColorsV2 colors, AppTextTheme text) {
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
                Text('SEND TO', style: context.themeText.receiveLabel?.copyWith(color: colors.textLabel)),
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
    final isFlipped = ref.watch(isCurrencyFlippedProvider);
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
        controller: _amountController,
        focusNode: _amountFocus,
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
              const SizedBox(width: 8),
              QuantusIconButton.circular(
                icon: Icons.swap_vert,
                onTap: _toggleFlip,
                isActive: display.isFlipped,
                size: IconButtonSize.small,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomSection(
    AppColorsV2 colors,
    AppTextTheme text,
    String btnText,
    AsyncValue<BigInt> balance,
    bool btnDisabled,
  ) {
    final formattingService = ref.read(numberFormattingServiceProvider);

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
                        Text('Available Balance:', style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
                        const SizedBox(height: 4),
                        balance.when(
                          data: (b) => Text(
                            '${formattingService.formatBalance(b)} ${AppConstants.tokenSymbol}',
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
                        Text('Network Fee:', style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
                        const SizedBox(height: 4),
                        if (!_isFetchingFee)
                          Text(
                            '${formattingService.formatBalance(_networkFee, maxDecimals: 5)} ${AppConstants.tokenSymbol}',
                            style: text.smallParagraph?.copyWith(color: colors.textTertiary),
                          )
                        else
                          const Loader(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              IntrinsicWidth(
                child: QuantusButton.simple(
                  label: 'Max',
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
            label: btnText,
            variant: ButtonVariant.primary,
            isDisabled: btnDisabled,
            onTap: _openReview,
          ),
        ],
      ),
    );
  }
}
