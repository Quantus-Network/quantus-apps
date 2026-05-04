import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
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

  final Map<String, String> _checksums = {};
  List<String> _recents = [];
  bool _hasAddressError = true;
  bool _loadingRecents = true;
  bool _isPayMode = false;
  String? _recipientChecksum;

  @override
  void initState() {
    super.initState();
    _recipientController.addListener(_onRecipientChanged);
    _loadRecents();
  }

  @override
  void dispose() {
    _recipientController.removeListener(_onRecipientChanged);
    _recipientController.dispose();
    _amountController.dispose();
    _recipientFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final checksumService = ref.read(humanReadableChecksumServiceProvider);
    final settingsService = ref.read(settingsServiceProvider);
    final recentAddressesService = ref.read(recentAddressesServiceProvider);

    try {
      final all = await recentAddressesService.getAddresses();
      final active = await settingsService.getActiveAccount();
      final currentId = active?.account.accountId;
      final addresses = all.where((a) => a != currentId).toList();
      if (!mounted) return;
      setState(() {
        _recents = addresses;
        _loadingRecents = false;
      });
      for (final addr in addresses) {
        checksumService.getHumanReadableName(addr).then((name) {
          if (mounted) setState(() => _checksums[addr] = name);
        });
      }
    } catch (e) {
      debugPrint('SelectRecipientScreen recents: $e');
      if (mounted) setState(() => _loadingRecents = false);
    }
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
    ref.watch(activeAccountProvider);
    final colors = context.colors;
    final text = context.themeText;

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
              _buildRecipientField(colors, text),
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
              slivers: [
                if (_loadingRecents)
                  const SliverFillRemaining(hasScrollBody: false, child: Center(child: Loader()))
                else if (_recents.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Text('Recents', style: text.smallTitle?.copyWith(color: colors.textPrimary)),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final isFirst = i == 0;
                      final isLast = i == _recents.length - 1;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isFirst) ...[const SizedBox(height: 14)],
                          _recentRow(_recents[i], colors, text),
                          if (!isLast) ...[
                            const SizedBox(height: 14),
                            Divider(height: 1, color: colors.txItemSeparator),
                          ],
                        ],
                      );
                    }, childCount: _recents.length),
                  ),
                ] else
                  const SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ),
      bottomContent: _buildBottomButton(),
    );
  }

  Widget _buildRecipientField(AppColorsV2 colors, AppTextTheme text) {
    final hasValid = _recipientController.text.trim().isNotEmpty && !_hasAddressError;

    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: hasValid,
              child: Opacity(
                opacity: hasValid ? 0 : 1,
                child: Container(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 14, color: colors.textLabel),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _recipientController,
                          focusNode: _recipientFocus,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.none,
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          style: text.smallParagraph?.copyWith(color: colors.textPrimary),
                          decoration: const InputDecoration(hintText: 'Search ${AppConstants.tokenSymbol} Address'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasValid)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _recipientController.clear();
                  _recipientFocus.requestFocus();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: colors.toasterBackground, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AddressFormattingService.formatAddress(_recipientController.text.trim()),
                        style: text.smallParagraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_recipientChecksum != null)
                        Text(_recipientChecksum!, style: text.detail?.copyWith(color: colors.checksum)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
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

  Widget _recentRow(String address, AppColorsV2 colors, AppTextTheme text) {
    final checksum = _checksums[address];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onRecentTap(address),
        borderRadius: BorderRadius.circular(8),
        child: checksum != null
            ? AddressCheckphraseWithInitial(recipientChecksum: checksum, recipientAddress: address)
            : const Skeleton(height: 36),
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
