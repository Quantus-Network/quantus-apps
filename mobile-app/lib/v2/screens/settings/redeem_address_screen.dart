import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/address_input_field.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/redeem_progress_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Fullscreen flow to pick a destination address for redeeming mining
/// rewards. Defaults the field to the user's primary account (Account 0).
class RedeemAddressScreen extends ConsumerStatefulWidget {
  final BigInt redeemableRewards;

  const RedeemAddressScreen({super.key, required this.redeemableRewards});

  @override
  ConsumerState<RedeemAddressScreen> createState() => _RedeemAddressScreenState();
}

class _RedeemAddressScreenState extends ConsumerState<RedeemAddressScreen> {
  final _recipientController = TextEditingController();
  final _recipientFocus = FocusNode();

  bool _hasAddressError = true;
  String? _recipientChecksum;

  @override
  void initState() {
    super.initState();
    _recipientController.addListener(_onRecipientChanged);
    _prefillPrimaryAccount();
  }

  @override
  void dispose() {
    _recipientController.removeListener(_onRecipientChanged);
    _recipientController.dispose();
    _recipientFocus.dispose();
    super.dispose();
  }

  Future<void> _prefillPrimaryAccount() async {
    final settings = ref.read(settingsServiceProvider);
    final primary = await settings.getAccount(walletIndex: 0, index: 0);
    if (!mounted || primary == null) return;
    _recipientController.text = primary.accountId;
  }

  void _onRecipientChanged() {
    final text = _recipientController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _hasAddressError = true;
        _recipientChecksum = null;
      });
      return;
    }
    final substrate = ref.read(substrateServiceProvider);
    final isValid = substrate.isValidSS58Address(text);
    setState(() {
      _hasAddressError = !isValid;
      _recipientChecksum = null;
    });
    if (isValid) {
      ref.read(humanReadableChecksumServiceProvider).getHumanReadableName(text).then((checksum) {
        if (mounted) setState(() => _recipientChecksum = checksum);
      });
    }
  }

  bool get _canRedeem =>
      _recipientController.text.trim().isNotEmpty && !_hasAddressError && widget.redeemableRewards > BigInt.zero;

  Future<void> _redeem() async {
    if (!_canRedeem) return;
    final destination = _recipientController.text.trim();
    final fmt = ref.read(numberFormattingServiceProvider);
    final formatted = fmt.formatBalance(widget.redeemableRewards, maxDecimals: 2, addSymbol: true);
    final l10n = ref.read(l10nProvider);

    final confirmed = await BottomSheetContainer.show<bool>(
      context,
      builder: (_) => _RedeemConfirmSheet(formatted: formatted, destination: destination, l10n: l10n),
    );
    if (confirmed != true || !mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            RedeemProgressScreen(redeemableRewards: widget.redeemableRewards, destinationAddress: destination),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final l10n = ref.watch(l10nProvider);

    final hasValid = _recipientController.text.trim().isNotEmpty && !_hasAddressError;
    final amountLabel = fmt.formatBalance(widget.redeemableRewards, maxDecimals: 2, addSymbol: true);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.settingsMiningRedeem),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountSummary(amountLabel: amountLabel, colors: colors, text: text, l10n: l10n),
          const SizedBox(height: 28),
          Text(l10n.redeemToLabel, style: text.sendSectionLabel?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 12),
          AddressInputField(
            controller: _recipientController,
            focusNode: _recipientFocus,
            hasValid: hasValid,
            recipientChecksum: _recipientChecksum,
            hintText: l10n.redeemAddressHint(AppConstants.tokenSymbol),
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: _canRedeem ? l10n.redeemAmountCta(amountLabel) : l10n.sendEnterAddress,
          variant: ButtonVariant.primary,
          isDisabled: !_canRedeem,
          onTap: _redeem,
        ),
      ),
    );
  }
}

class _AmountSummary extends StatelessWidget {
  final String amountLabel;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final AppLocalizations l10n;

  const _AmountSummary({required this.amountLabel, required this.colors, required this.text, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.settingsMiningStatRedeemable, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              amountLabel,
              maxLines: 1,
              softWrap: false,
              style: text.sendSectionLabel?.copyWith(color: colors.success),
            ),
          ),
        ],
      ),
    );
  }
}

class _RedeemConfirmSheet extends StatelessWidget {
  final String formatted;
  final String destination;
  final AppLocalizations l10n;

  const _RedeemConfirmSheet({required this.formatted, required this.destination, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return BottomSheetContainer(
      title: l10n.redeemConfirmTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(l10n.redeemConfirmAmount, formatted, colors, text),
          Divider(color: colors.separator, height: 32),
          _row(l10n.redeemConfirmTo, AddressFormattingService.formatAddress(destination), colors, text),
          Divider(color: colors.separator, height: 32),
          _row(l10n.redeemConfirmFee, l10n.redeemFeeValue, colors, text),
          const SizedBox(height: 32),
          QuantusButton.simple(label: l10n.redeemAmountCta(formatted), onTap: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, AppColorsV2 colors, AppTextTheme text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.smallParagraph?.copyWith(color: colors.textSecondary)),
        Flexible(
          child: Text(
            value,
            style: text.smallParagraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
