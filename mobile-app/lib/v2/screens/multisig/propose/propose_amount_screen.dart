import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/amount_input_logic.dart';
import 'package:resonance_network_wallet/shared/utils/debouncer.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/propose/propose_review_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_screen_logic.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ProposeAmountScreen extends ConsumerStatefulWidget {
  final MultisigAccount msig;
  final String recipientAddress;
  final String? recipientChecksum;
  final String? initialAmount;
  final bool isPayMode;

  const ProposeAmountScreen({
    super.key,
    required this.msig,
    required this.recipientAddress,
    this.recipientChecksum,
    this.initialAmount,
    this.isPayMode = false,
  });

  @override
  ConsumerState<ProposeAmountScreen> createState() => _ProposeAmountScreenState();
}

class _ProposeAmountScreenState extends ConsumerState<ProposeAmountScreen> {
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  final _scrollController = ScrollController();
  final _amountCenterKey = GlobalKey();
  final _feeDebouncer = Debouncer(delay: const Duration(milliseconds: 500));

  static final BigInt _estimateFeeAmount = BigInt.from(1000) * NumberFormattingService.scaleFactorBigInt;

  String? _recipientChecksum;
  BigInt _amount = BigInt.zero;
  ProposeFeeBreakdown? _feeBreakdown;
  bool _isFetchingFee = false;
  bool _hasFee = false;
  bool _feeFetchFailed = false;
  int _feeFetchGeneration = 0;

  AmountInputLogic get _amountInputLogic => AmountInputLogic(
    exchangeRateService: ref.read(exchangeRateServiceProvider),
    selectedFiat: ref.read(selectedFiatCurrencyProvider),
    localeConfig: ref.read(localeNumberConfigProvider),
    formattingService: ref.read(numberFormattingServiceProvider),
  );

  @override
  void initState() {
    super.initState();
    assert(widget.recipientAddress.trim().isNotEmpty, 'ProposeAmountScreen requires a recipient');
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
      ref.read(humanReadableChecksumServiceProvider).getHumanReadableName(widget.recipientAddress.trim()).then((name) {
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
    final isFlipped = widget.isPayMode ? false : ref.read(isCurrencyFlippedProvider);
    try {
      setState(() => _amount = _amountInputLogic.onAmountChanged(value: _amountController.text, isFlipped: isFlipped));
    } on InvalidNumberInputException catch (e, stack) {
      debugPrint('Amount parse failed: $e\n$stack');
      context.showErrorToaster(message: ref.read(l10nProvider).sendInputAmountInvalidAmount);
      return;
    }
    _feeDebouncer.run(_refreshFee);
  }

  void _refreshFee() {
    final recipient = widget.recipientAddress.trim();
    if (_amount > BigInt.zero && ref.read(substrateServiceProvider).isValidSS58Address(recipient)) {
      _fetchFee(_amount, recipient);
    } else {
      _fetchEstimatedFee();
    }
  }

  void _retryFeeFetch() {
    _feeDebouncer.cancel();
    _refreshFee();
  }

  Future<void> _fetchEstimatedFee() async {
    _fetchFee(_estimateFeeAmount, widget.recipientAddress.trim());
  }

  ProposeFeeBreakdown _staticFeeBreakdown(MultisigService service, int expiryBlock) {
    return ProposeFeeBreakdown(
      networkFee: BigInt.zero,
      deposit: service.proposalDeposit,
      creationFee: service.proposalCreationFee(widget.msig.signers.length),
      expiryBlock: expiryBlock,
    );
  }

  Future<void> _fetchFee(BigInt amount, String recipient) async {
    final generation = ++_feeFetchGeneration;
    final showLoader = !_hasFee || _feeFetchFailed;
    final service = ref.read(multisigServiceProvider);
    Account? signer;
    final accounts = ref.read(accountsProvider).value;
    if (accounts != null) {
      for (final account in accounts) {
        if (account.accountId == widget.msig.myMemberAccountId) {
          signer = account;
          break;
        }
      }
    }
    setState(() {
      _isFetchingFee = showLoader;
      if (showLoader) _feeFetchFailed = false;
    });
    try {
      final currentBlock = await service.currentBlockNumber();
      final expiryBlock = currentBlock + service.blocksForDuration(MultisigService.defaultProposalExpiry);
      final breakdown = signer != null
          ? await service.estimateProposeFeeBreakdown(
              msig: widget.msig,
              signer: signer,
              recipient: recipient,
              amount: amount,
            )
          : _staticFeeBreakdown(service, expiryBlock);
      if (!mounted || generation != _feeFetchGeneration) return;
      setState(() {
        _feeBreakdown = breakdown;
        _hasFee = true;
        _feeFetchFailed = false;
        _isFetchingFee = false;
      });
    } catch (e, stack) {
      debugPrint('Propose fee fetch error: $e\n$stack');
      if (!mounted || generation != _feeFetchGeneration) return;
      setState(() {
        _feeBreakdown = null;
        _hasFee = false;
        _feeFetchFailed = true;
        _isFetchingFee = false;
      });
    }
  }

  void _setMax() {
    final balance = ref.read(balanceProviderFamily(widget.msig.accountId)).value ?? BigInt.zero;
    final isFlipped = ref.read(isCurrencyFlippedProvider);
    _amountController.text = isFlipped
        ? _amountInputLogic.quanToFiatString(balance)
        : _amountInputLogic.formatQuanAmount(balance);
    setState(() => _amount = balance);
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
    if (_recipientChecksum == null || _feeBreakdown == null) {
      context.showErrorToaster(message: ref.read(l10nProvider).sendInputAmountChecksumRequired);
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProposeReviewScreen(
          msig: widget.msig,
          recipientAddress: widget.recipientAddress,
          recipientChecksum: _recipientChecksum!,
          amount: _amount,
          feeBreakdown: _feeBreakdown!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final balance = ref.watch(balanceProviderFamily(widget.msig.accountId));
    final memberBalance = ref.watch(effectiveBalanceProviderFamily(widget.msig.myMemberAccountId));
    final formattingService = ref.read(numberFormattingServiceProvider);
    final recipient = widget.recipientAddress.trim();

    final multisigBalance = balance.value;
    final memberBal = memberBalance.value;
    final proposalFee = _feeBreakdown?.memberCost;

    final amountStatus = SendScreenLogic.getAmountStatus(_amount, multisigBalance ?? BigInt.zero, BigInt.zero);
    final multisigInsufficient = amountStatus == AmountStatus.insufficientBalance;
    final memberInsufficient = proposalFee != null && memberBal != null && memberBal < proposalFee;
    final balancesLoading = balance.isLoading || memberBalance.isLoading;

    final btnDisabled =
        !_hasFee ||
        _feeFetchFailed ||
        _recipientChecksum == null ||
        balancesLoading ||
        memberInsufficient ||
        SendScreenLogic.isButtonDisabled(
          hasAddressError: false,
          amountStatus: amountStatus,
          recipientText: recipient,
          activeAccountId: widget.msig.accountId,
        );
    final btnText = memberInsufficient
        ? l10n.sendLogicInsufficientBalance
        : multisigInsufficient
        ? l10n.sendLogicInsufficientBalance
        : amountStatus == AmountStatus.valid
        ? l10n.multisigProposeReviewButton
        : SendScreenLogic.getButtonText(
            l10n: l10n,
            hasAddressError: false,
            amountStatus: amountStatus,
            recipientText: recipient,
            amount: _amount,
            activeAccountId: widget.msig.accountId,
            formattingService: formattingService,
          );

    return ScaffoldBase(
      appBar: V2AppBar(title: widget.isPayMode ? l10n.sendPayTitle : l10n.multisigProposeTitle),
      mainContent: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: _scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _recipientCard(colors, text, l10n),
                const SizedBox(height: 32),
                _amountCenter(colors, text),
                const SizedBox(height: 32),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
      bottomContent: _bottomSection(colors, text, l10n, btnText, balance, btnDisabled),
    );
  }

  Widget _recipientCard(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
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
                  l10n.multisigProposeAmountToLabel,
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

  Widget _bottomSection(
    AppColorsV2 colors,
    AppTextTheme text,
    AppLocalizations l10n,
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
                        Text(
                          l10n.multisigProposeFeeLabel,
                          style: text.smallParagraph?.copyWith(color: colors.textTertiary),
                        ),
                        const SizedBox(height: 4),
                        if (_isFetchingFee)
                          const Align(alignment: Alignment.centerRight, child: Loader())
                        else if (_feeFetchFailed)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                l10n.multisigProposeFeeFetchFailed,
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
                          )
                        else if (_hasFee && _feeBreakdown != null)
                          Text(
                            l10n.commonAmountBalance(
                              formattingService.formatBalance(_feeBreakdown!.memberCost, maxDecimals: 5),
                              AppConstants.tokenSymbol,
                            ),
                            style: text.smallParagraph?.copyWith(color: colors.textTertiary),
                          )
                        else
                          const Align(alignment: Alignment.centerRight, child: Loader()),
                      ],
                    ),
                  ),
                ],
              ),
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
