import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/propose/propose_done_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

const Duration kDefaultProposalExpiry = Duration(days: 2);

class ProposeReviewScreen extends ConsumerStatefulWidget {
  final MultisigAccount msig;
  final String recipientAddress;
  final String recipientChecksum;
  final BigInt amount;
  final BigInt proposalFee;

  const ProposeReviewScreen({
    super.key,
    required this.msig,
    required this.recipientAddress,
    required this.recipientChecksum,
    required this.amount,
    required this.proposalFee,
  });

  @override
  ConsumerState<ProposeReviewScreen> createState() => _ProposeReviewScreenState();
}

class _ProposeReviewScreenState extends ConsumerState<ProposeReviewScreen> {
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final l10n = ref.read(l10nProvider);
    final authed = await LocalAuthService().authenticate(localizedReason: l10n.multisigProposeAuthReason);
    if (!authed || !mounted) {
      setState(() {
        _submitting = false;
        _errorMessage = l10n.multisigProposeAuthRequired;
      });
      return;
    }
    try {
      final signer = ref.read(accountsProvider).value?.firstWhere(
            (a) => a.accountId == widget.msig.myMemberAccountId,
            orElse: () => throw Exception('Member account not found in local wallet'),
          );
      if (signer == null) throw Exception('No signer account available');

      final service = ref.read(multisigServiceProvider);
      final currentBlock = await service.currentBlockNumber();
      final expiryBlock = service.timeToBlock(DateTime.now().add(kDefaultProposalExpiry));

      final proposalId = await service.propose(
        msig: widget.msig,
        signer: signer,
        recipient: widget.recipientAddress,
        amount: widget.amount,
        expiryBlock: expiryBlock,
      );

      if (!mounted) return;
      ref.invalidate(multisigOpenProposalsProvider(widget.msig));
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProposeDoneScreen(
            msig: widget.msig,
            recipientAddress: widget.recipientAddress,
            recipientChecksum: widget.recipientChecksum,
            amount: widget.amount,
            proposalId: proposalId,
            myApprovalCount: 1,
            currentBlock: currentBlock,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Propose submit error: $e $st');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = ref.read(l10nProvider).multisigProposeSubmitFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final totalRaw = widget.amount + widget.proposalFee;
    final shortAddr = AddressFormattingService.formatAddress(widget.recipientAddress);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.multisigProposeTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroCard(l10n, colors, text, fmt),
          const SizedBox(height: 28),
          _summary(l10n, colors, text, shortAddr, totalRaw, fmt),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: text.detail?.copyWith(color: colors.textError)),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.multisigProposeCreateButton,
          variant: ButtonVariant.primary,
          isLoading: _submitting,
          isDisabled: _submitting,
          onTap: _submit,
        ),
      ),
    );
  }

  Widget _heroCard(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text, NumberFormattingService fmt) {
    final labelStyle = text.receiveLabel?.copyWith(color: colors.textLabel);

    return SplitCard(
      topChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.multisigProposeReviewProposing, style: labelStyle),
          const SizedBox(height: 16),
          Text(
            '${fmt.formatBalance(widget.amount, maxDecimals: 4)} ${AppConstants.tokenSymbol}',
            style: text.extraLargeTitle?.copyWith(
              color: colors.textPrimary,
              fontFamily: AppTextTheme.fontFamilySecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.multisigProposeReviewFromName(widget.msig.name),
            style: text.smallParagraph?.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
      bottomChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sendReviewTo, style: labelStyle),
          const SizedBox(height: 16),
          AddressCheckphraseWithInitial(
            recipientChecksum: widget.recipientChecksum,
            recipientAddress: widget.recipientAddress,
          ),
        ],
      ),
    );
  }

  Widget _summary(
    AppLocalizations l10n,
    AppColorsV2 colors,
    AppTextTheme text,
    String shortAddr,
    BigInt totalRaw,
    NumberFormattingService fmt,
  ) {
    final shownDecimals = AppConstants.decimals;
    final expiry = DateTime.now().add(kDefaultProposalExpiry);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 7),
        _row(l10n.sendReviewTo, shortAddr),
        const SizedBox(height: 7),
        _row(
          l10n.sendReviewAmount,
          '${fmt.formatBalance(widget.amount, maxDecimals: shownDecimals)} ${AppConstants.tokenSymbol}',
        ),
        const SizedBox(height: 7),
        _row(l10n.multisigProposeThresholdLabel, '${widget.msig.threshold}/${widget.msig.signers.length}'),
        const SizedBox(height: 7),
        _row(l10n.multisigProposeExpiresLabel, DatetimeFormattingService.formatTxDateTime(expiry)),
        const SizedBox(height: 7),
        _row(
          l10n.multisigProposeFeeRowLabel,
          '${fmt.formatBalance(widget.proposalFee, maxDecimals: shownDecimals)} ${AppConstants.tokenSymbol}',
        ),
        const SizedBox(height: 7),
        _row(
          l10n.sendReviewYouPay,
          '${fmt.formatBalance(totalRaw, maxDecimals: shownDecimals)} ${AppConstants.tokenSymbol}',
        ),
        const SizedBox(height: 7),
      ],
    );
  }

  Widget _row(String label, String value) {
    final labelStyle = context.themeText.transactionDetailRowLabel?.copyWith(color: context.colors.textTertiary);
    final valueStyle = context.themeText.transactionDetailRowLabel;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 8),
        Flexible(child: Text(value, style: valueStyle, textAlign: TextAlign.right)),
      ],
    );
  }
}
