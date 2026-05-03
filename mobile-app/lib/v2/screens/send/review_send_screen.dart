import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/send/tx_submitted_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ReviewSendScreen extends ConsumerStatefulWidget {
  final String recipientAddress;
  final BigInt amount;
  final BigInt networkFee;
  final int blockHeight;
  final String recipientChecksum;
  final bool isPayMode;

  const ReviewSendScreen({
    super.key,
    required this.recipientAddress,
    required this.amount,
    required this.networkFee,
    required this.blockHeight,
    required this.recipientChecksum,
    this.isPayMode = false,
  });

  @override
  ConsumerState<ReviewSendScreen> createState() => _ReviewSendScreenState();
}

class _ReviewSendScreenState extends ConsumerState<ReviewSendScreen> {
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _toggleFlip() async {
    await ref.read(isCurrencyFlippedProvider.notifier).toggle();
  }

  Future<void> _confirmSend() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final authed = await LocalAuthService().authenticate(localizedReason: 'Authenticate to confirm transaction');
    if (!authed || !mounted) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Authentication required to send';
      });
      return;
    }

    try {
      final settings = SettingsService();
      final account = (await settings.getActiveRegularAccount())!;
      final submissionService = ref.read(transactionSubmissionServiceProvider);
      await submissionService.balanceTransfer(
        account,
        widget.recipientAddress.trim(),
        widget.amount,
        widget.networkFee,
        widget.blockHeight,
      );
      RecentAddressesService().addAddress(widget.recipientAddress.trim());
      setState(() {
        _submitting = false;
        _errorMessage = null;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TxSubmittedScreen(
              amount: widget.amount,
              recipientAddress: widget.recipientAddress,
              recipientChecksum: widget.recipientChecksum,
              isPayMode: widget.isPayMode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'Transfer failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(activeAccountProvider);
    final colors = context.colors;
    final text = context.themeText;
    final addr = widget.recipientAddress.trim();
    final approxDisplay = ref.watch(txAmountDisplayProvider)(
      widget.amount,
      isSend: true,
      withSignPrefix: false,
      withQuanSymbol: false,
      quanDecimals: 4,
    );
    final totalRaw = widget.amount + widget.networkFee;

    return ScaffoldBase(
      appBar: V2AppBar(title: widget.isPayMode ? 'Pay' : 'Send'),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heroCard(colors, text, approxDisplay),
              const SizedBox(height: 28),
              _summarySection(addr, totalRaw),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: text.detail?.copyWith(color: colors.textError)),
              ],
            ],
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: 'Confirm',
          variant: ButtonVariant.primary,
          isLoading: _submitting,
          isDisabled: _submitting,
          onTap: _confirmSend,
        ),
      ),
    );
  }

  Widget _heroCard(AppColorsV2 colors, AppTextTheme text, CurrencyDisplayState approxDisplay) {
    final sectionLabelStyle = text.receiveLabel?.copyWith(color: colors.textLabel);

    return SplitCard(
      topChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SENDING', style: sectionLabelStyle),
          const SizedBox(height: 16),
          AmountDisplayWithConversion(
            amountDisplay: approxDisplay,
            alignment: CrossAxisAlignment.start,
            onFlip: _toggleFlip,
          ),
        ],
      ),
      bottomChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TO', style: sectionLabelStyle),
          const SizedBox(height: 16),
          AddressCheckphraseWithInitial(
            recipientChecksum: widget.recipientChecksum,
            recipientAddress: widget.recipientAddress,
          ),
        ],
      ),
    );
  }

  Widget _summarySection(String addr, BigInt totalRaw) {
    final shownDecimals = AppConstants.decimals;
    final shortAddr = AddressFormattingService.formatAddress(addr);
    final formattingService = ref.watch(numberFormattingServiceProvider);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 7),
        _summaryRow(label: 'TO', value: shortAddr),
        const SizedBox(height: 7),
        _summaryRow(
          label: 'AMOUNT',
          value:
              '${formattingService.formatBalance(widget.amount, maxDecimals: shownDecimals)} ${AppConstants.tokenSymbol}',
        ),
        const SizedBox(height: 7),
        _summaryRow(
          label: 'NETWORK FEE',
          value:
              '${formattingService.formatBalance(widget.networkFee, maxDecimals: shownDecimals)} ${AppConstants.tokenSymbol}',
        ),
        const SizedBox(height: 7),
        _summaryRow(
          label: 'YOU PAY',
          value: '${formattingService.formatBalance(totalRaw, maxDecimals: shownDecimals)} ${AppConstants.tokenSymbol}',
        ),
        const SizedBox(height: 7),
      ],
    );
  }

  Widget _summaryRow({required String label, required String value}) {
    final labelStyle = context.themeText.transactionDetailRowLabel?.copyWith(color: context.colors.textTertiary);
    final valueStyle = context.themeText.transactionDetailRowLabel;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(value, style: valueStyle, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
