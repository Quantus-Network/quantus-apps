import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/amount_input_logic.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/pos/pos_qr_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class PosAmountScreen extends ConsumerStatefulWidget {
  const PosAmountScreen({super.key});

  @override
  ConsumerState<PosAmountScreen> createState() => _PosAmountScreenState();
}

class _PosAmountScreenState extends ConsumerState<PosAmountScreen> {
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();
  BigInt _amount = BigInt.zero;

  AmountInputLogic get _amountInputLogic => AmountInputLogic(
    exchangeRateService: ref.read(exchangeRateServiceProvider),
    selectedFiat: ref.read(selectedFiatCurrencyProvider),
    localeConfig: ref.read(localeNumberConfigProvider),
    formattingService: ref.read(numberFormattingServiceProvider),
  );

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _onAmountChanged(String _) {
    final isFlipped = ref.read(isCurrencyFlippedProvider);
    try {
      setState(() => _amount = _amountInputLogic.onAmountChanged(value: _amountController.text, isFlipped: isFlipped));
    } on InvalidNumberInputException catch (e, stack) {
      debugPrint('Amount parse failed: $e\n$stack');
      context.showErrorToaster(message: ref.read(l10nProvider).sendInputAmountInvalidAmount);
      return;
    }
  }

  void _onCharge() {
    if (_amount <= BigInt.zero) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PosQrScreen(amountPlanck: _amount)));
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

  bool get _isValid => _amount > BigInt.zero;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final primaryAmount = ref
        .watch(txAmountDisplayProvider)(_amount, withSignPrefix: false, isSend: true)
        .primaryAmount;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.posAmountTitle),
      mainContent: _amountCenter(colors, text),
      bottomContent: _bottomContent(l10n, primaryAmount),
    );
  }

  Widget _amountCenter(AppColorsV2 colors, AppTextTheme text) {
    final isFlipped = ref.watch(isCurrencyFlippedProvider);
    final selectedFiat = ref.watch(selectedFiatCurrencyProvider);
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
        inputFormatters: [
          DecimalInputFilter(localeConfig: ref.read(localeNumberConfigProvider), maxDecimalPlaces: maxDecimals),
        ],
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

  Widget _bottomContent(AppLocalizations l10n, String amountDisplay) {
    final label = _amount > BigInt.zero ? l10n.posAmountCharge(amountDisplay) : l10n.posAmountEnterAmount;

    return ScaffoldBaseBottomContent(
      child: QuantusButton.simple(label: label, onTap: _onCharge, isDisabled: !_isValid),
    );
  }
}
