import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/address_input_field.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/recent_addresses_list.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
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
  bool _submitting = false;

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
      !_submitting &&
      _recipientController.text.trim().isNotEmpty &&
      !_hasAddressError &&
      widget.redeemableRewards > BigInt.zero;

  Future<void> _redeem() async {
    if (!_canRedeem) return;
    final destination = _recipientController.text.trim();
    final fmt = ref.read(numberFormattingServiceProvider);
    final formatted = fmt.formatBalance(widget.redeemableRewards, maxDecimals: 2, addSymbol: true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Redeem Rewards?'),
        content: Text('Send $formatted to:\n\n$destination'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Redeem')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    // ignore: avoid_print
    print('[Redeem] STUB: $formatted -> $destination');
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redeem flow not wired yet (stub).')));
  }

  void _onRecentTap(String address) => _recipientController.text = address;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);

    final hasValid = _recipientController.text.trim().isNotEmpty && !_hasAddressError;
    final amountLabel = fmt.formatBalance(widget.redeemableRewards, maxDecimals: 2, addSymbol: true);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Redeem'),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountSummary(amountLabel: amountLabel, colors: colors, text: text),
          const SizedBox(height: 28),
          Text('Redeem To', style: text.sendSectionLabel?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 12),
          AddressInputField(
            controller: _recipientController,
            focusNode: _recipientFocus,
            hasValid: hasValid,
            recipientChecksum: _recipientChecksum,
            hintText: 'Paste a ${AppConstants.tokenSymbol} Address',
          ),
          const SizedBox(height: 28),
          Expanded(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [RecentAddressesSlivers(excludeAddresses: const <String>{}, onTap: _onRecentTap)],
            ),
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: _canRedeem ? 'Redeem $amountLabel' : 'Enter Address',
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

  const _AmountSummary({required this.amountLabel, required this.colors, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('REDEEMABLE', style: text.receiveLabel?.copyWith(color: colors.textLabel)),
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
