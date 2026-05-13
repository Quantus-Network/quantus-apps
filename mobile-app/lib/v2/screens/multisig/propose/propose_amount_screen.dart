import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/amount_input_logic.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/propose/propose_review_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ProposeAmountScreen extends ConsumerStatefulWidget {
  final MultisigAccount msig;
  final String recipientAddress;
  final String? recipientChecksum;

  const ProposeAmountScreen({
    super.key,
    required this.msig,
    required this.recipientAddress,
    this.recipientChecksum,
  });

  @override
  ConsumerState<ProposeAmountScreen> createState() => _ProposeAmountScreenState();
}

class _ProposeAmountScreenState extends ConsumerState<ProposeAmountScreen> {
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  String? _recipientChecksum;
  BigInt _amount = BigInt.zero;
  BigInt _proposalFee = BigInt.zero;
  bool _isFetchingFee = true;

  AmountInputLogic get _inputLogic => AmountInputLogic(
        exchangeRateService: ref.read(exchangeRateServiceProvider),
        selectedFiat: ref.read(selectedFiatCurrencyProvider),
        localeConfig: ref.read(localeNumberConfigProvider),
        formattingService: ref.read(numberFormattingServiceProvider),
      );

  @override
  void initState() {
    super.initState();
    _recipientChecksum = widget.recipientChecksum;
    if (_recipientChecksum == null) {
      ref.read(humanReadableChecksumServiceProvider).getHumanReadableName(widget.recipientAddress).then((c) {
        if (mounted) setState(() => _recipientChecksum = c);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchFee());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchFee() async {
    try {
      final fee = await ref
          .read(multisigServiceProvider)
          .estimateProposeFee(widget.msig, widget.recipientAddress, _amount > BigInt.zero ? _amount : BigInt.one);
      if (!mounted) return;
      setState(() {
        _proposalFee = fee;
        _isFetchingFee = false;
      });
    } catch (e, st) {
      debugPrint('Propose fee fetch error: $e $st');
      if (!mounted) return;
      setState(() => _isFetchingFee = false);
    }
  }

  void _onAmountChanged(String _) {
    try {
      setState(() => _amount = _inputLogic.onAmountChanged(value: _amountController.text, isFlipped: false));
    } on InvalidNumberInputException catch (e, st) {
      debugPrint('Amount parse failed: $e $st');
      context.showErrorToaster(message: 'Please enter a valid amount');
    }
  }

  void _setMax(BigInt balance) {
    _amountController.text = _inputLogic.formatQuanAmount(balance);
    setState(() => _amount = balance);
  }

  void _openReview() {
    if (_recipientChecksum == null) {
      context.showErrorToaster(message: 'Recipient checksum is required');
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
          proposalFee: _proposalFee,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final balanceAsync = ref.watch(balanceProviderFamily(widget.msig.accountId));
    final balance = balanceAsync.value ?? BigInt.zero;
    final canSubmit = _amount > BigInt.zero && _amount <= balance && !_isFetchingFee && _recipientChecksum != null;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Propose'),
      mainContent: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
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
      bottomContent: _bottomSection(colors, text, balanceAsync, canSubmit),
    );
  }

  Widget _recipientCard(AppColorsV2 colors, AppTextTheme text) {
    final shortAddr = AddressFormattingService.formatAddress(widget.recipientAddress);
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
                Text('PROPOSE TO', style: text.receiveLabel?.copyWith(color: colors.textLabel)),
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
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.borderButton)),
                child: Icon(Icons.edit_outlined, size: 18, color: colors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountCenter(AppColorsV2 colors, AppTextTheme text) {
    final localeConfig = ref.watch(localeNumberConfigProvider);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IntrinsicWidth(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IntrinsicWidth(
                  child: TextField(
                    controller: _amountController,
                    focusNode: _amountFocus,
                    onChanged: _onAmountChanged,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    inputFormatters: [DecimalInputFilter(localeConfig: localeConfig)],
                    style: text.transactionDetailAmountPrimary?.copyWith(
                      color: _amount == BigInt.zero ? colors.textTertiary : colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '0',
                      hintStyle: text.transactionDetailAmountPrimary?.copyWith(color: colors.textTertiary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppConstants.tokenSymbol,
                  style: text.transactionDetailAmountSymbol?.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'from ${widget.msig.name}',
            style: text.paragraph?.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _bottomSection(AppColorsV2 colors, AppTextTheme text, AsyncValue<BigInt> balanceAsync, bool canSubmit) {
    final formattingService = ref.read(numberFormattingServiceProvider);

    return ScaffoldBaseBottomContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Multisig Balance:', style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
                    const SizedBox(height: 4),
                    balanceAsync.when(
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
                    Text('Proposal Fee:', style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
                    const SizedBox(height: 4),
                    if (!_isFetchingFee)
                      Text(
                        '${formattingService.formatBalance(_proposalFee, maxDecimals: 5)} ${AppConstants.tokenSymbol}',
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
              onTap: () => _setMax(balanceAsync.value ?? BigInt.zero),
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              variant: ButtonVariant.transparent,
              textStyle: text.smallParagraph?.copyWith(
                color: colors.accentOrange,
                decoration: TextDecoration.underline,
                decorationColor: colors.accentOrange,
              ),
            ),
          ),
          const SizedBox(height: 32),
          QuantusButton.simple(
            label: 'Review Proposal',
            variant: ButtonVariant.primary,
            isDisabled: !canSubmit,
            onTap: _openReview,
          ),
        ],
      ),
    );
  }
}
