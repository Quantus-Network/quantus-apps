import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/address_input_field.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:resonance_network_wallet/v2/components/recent_addresses_list.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class SelectRecipientScreen extends ConsumerStatefulWidget {
  const SelectRecipientScreen({super.key});

  @override
  ConsumerState<SelectRecipientScreen> createState() => _SelectRecipientScreenState();
}

class _SelectRecipientScreenState extends ConsumerState<SelectRecipientScreen> {
  final _amountController = TextEditingController();
  final _recipientController = TextEditingController();
  final _recipientFocus = FocusNode();

  bool _hasAddressError = true;
  bool _isPayMode = false;
  String? _recipientChecksum;

  @override
  void initState() {
    super.initState();
    _recipientController.addListener(_onRecipientChanged);
  }

  @override
  void dispose() {
    _recipientController.removeListener(_onRecipientChanged);
    _recipientController.dispose();
    _amountController.dispose();
    _recipientFocus.dispose();
    super.dispose();
  }

  void _onRecipientChanged() {
    final text = _recipientController.text.trim();
    if (text.isEmpty) {
      _amountController.clear();
      setState(() {
        _hasAddressError = true;
        _recipientChecksum = null;
        _isPayMode = false;
      });
      return;
    }
    _lookupAddress(text);
  }

  void _lookupAddress(String address) {
    final checksumService = ref.read(humanReadableChecksumServiceProvider);
    final substrate = ref.read(substrateServiceProvider);
    final isValid = substrate.isValidSS58Address(address);
    setState(() {
      _hasAddressError = !isValid;
      _recipientChecksum = null;
    });
    if (isValid) {
      checksumService.getHumanReadableName(address).then((checksum) {
        if (mounted) setState(() => _recipientChecksum = checksum);
      });
    }
  }

  bool get _canContinue {
    final text = _recipientController.text.trim();
    if (text.isEmpty) return false;
    if (_hasAddressError) return false;
    final activeId = ref.read(activeAccountProvider).value?.account.accountId ?? '';
    if (text == activeId) return false;
    return true;
  }

  Future<void> _scanQr() async {
    final substrate = ref.read(substrateServiceProvider);
    final scanResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => QrScannerPage(
          validator: (code) => substrate.isValidSS58Address(code) || PaymentIntent.tryParseUrl(code) != null,
        ),
      ),
    );
    if (scanResult == null || !mounted) return;
    final payment = PaymentIntent.tryParseUrl(scanResult);
    if (payment != null) {
      setState(() {
        _recipientController.text = payment.to;
        _amountController.text = payment.amount;
        _isPayMode = true;
      });
    } else {
      setState(() {
        _recipientController.text = scanResult;
        _isPayMode = false;
      });
    }
  }

  void _continue() {
    if (!_canContinue) return;

    final address = _recipientController.text.trim();
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InputAmountScreen(
          recipientAddress: address,
          recipientChecksum: _recipientChecksum,
          initialAmount: _amountController.text,
          isPayMode: _isPayMode,
        ),
      ),
    ).then((popped) {
      if (!mounted || popped != true) return;
      _recipientController.clear();
      _amountController.clear();
      _isPayMode = false;

      setState(() {
        _recipientChecksum = null;
        _hasAddressError = true;
      });
    });
  }

  void _onRecentTap(String address) {
    _amountController.clear();
    setState(() => _isPayMode = false);
    _recipientController.text = address;
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeAccountProvider).value;
    final colors = context.colors;
    final text = context.themeText;

    final hasValid = _recipientController.text.trim().isNotEmpty && !_hasAddressError;
    final exclude = <String>{if (active != null) active.account.accountId};

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Send'),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Send To', style: text.sendSectionLabel?.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 12),
              AddressInputField(
                controller: _recipientController,
                focusNode: _recipientFocus,
                hasValid: hasValid,
                recipientChecksum: _recipientChecksum,
              ),
              const SizedBox(height: 28),
              _buildScanRow(colors, text),
              const SizedBox(height: 28),
              DottedBorder(
                dashLength: 3,
                gapLength: 5,
                color: colors.borderButton.useOpacity(0.5),
                child: const SizedBox(width: double.infinity, height: 1),
              ),
              const SizedBox(height: 28),
            ],
          ),
          Expanded(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [RecentAddressesSlivers(excludeAddresses: exclude, onTap: _onRecentTap)],
            ),
          ),
        ],
      ),
      bottomContent: _buildBottomButton(),
    );
  }

  Widget _buildScanRow(AppColorsV2 colors, AppTextTheme text) {
    final iconContainerSize = 44.0;
    final iconSize = 24.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _scanQr,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: iconContainerSize,
              height: iconContainerSize,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: colors.borderButton),
              ),
              child: Icon(Icons.qr_code_scanner, size: iconSize, color: colors.textPrimary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan QR code', style: text.paragraph?.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to scan a ${AppConstants.tokenSymbol} Address',
                    style: text.detail?.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.textPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    final btnText = _canContinue ? 'Continue' : 'Enter Address';

    return ScaffoldBaseBottomContent(
      child: QuantusButton.simple(
        label: btnText,
        variant: ButtonVariant.primary,
        isDisabled: !_canContinue,
        onTap: _continue,
      ),
    );
  }
}
