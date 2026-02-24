import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_screen_logic.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/v2/screens/send/address_picker_sheet.dart';

enum _Step { form, confirm, sending, complete }

class SendSheet extends ConsumerStatefulWidget {
  final String? initialAddress;
  const SendSheet({super.key, this.initialAddress});

  @override
  ConsumerState<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends ConsumerState<SendSheet> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _fmt = NumberFormattingService();
  final _checksumService = HumanReadableChecksumService();

  _Step _step = _Step.form;
  String? _recipientChecksum;
  bool _hasAddressError = true;
  BigInt _amount = BigInt.zero;
  BigInt _networkFee = BigInt.zero;
  int _blockHeight = 0;
  bool _isFetchingFee = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recipientController.addListener(_onRecipientChanged);
    _amountController.addListener(_onAmountChanged);
    if (widget.initialAddress != null) {
      _recipientController.text = widget.initialAddress!;
    }
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
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
    _lookupAddress(text);
  }

  Future<void> _lookupAddress(String address) async {
    final substrate = ref.read(substrateServiceProvider);
    final isValid = substrate.isValidSS58Address(address);
    final checksum = isValid ? await _checksumService.getHumanReadableName(address) : null;
    if (!mounted) return;
    setState(() {
      _hasAddressError = !isValid;
      _recipientChecksum = checksum;
    });
    if (isValid && _amount > BigInt.zero) _fetchFee();
  }

  void _onAmountChanged() {
    final parsed = _fmt.parseAmount(_amountController.text);
    setState(() => _amount = parsed ?? BigInt.zero);
    if (!_hasAddressError && _amount > BigInt.zero) _fetchFee();
  }

  Future<void> _fetchFee() async {
    if (_isFetchingFee) return;
    setState(() => _isFetchingFee = true);
    try {
      final displayAccount = ref.read(activeAccountProvider).value;
      if (displayAccount is! RegularAccount) return;
      final recipient = _recipientController.text.trim();
      final balancesService = ref.read(balancesServiceProvider);
      final feeData = await balancesService.getBalanceTransferFee(displayAccount.account, recipient, _amount);
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

  void _setMax() {
    final balance = ref.read(effectiveMaxBalanceProvider).value ?? BigInt.zero;
    final max = SendScreenLogic.calculateMaxSendableAmount(balance: balance, networkFee: _networkFee);
    _amountController.text = _fmt.formatBalance(max, addThousandsSeparators: false);
  }

  Future<void> _scanQr() async {
    final address = await Navigator.push<String>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const QrScannerPage()),
    );
    if (address != null && mounted) {
      _recipientController.text = address;
    }
  }

  Future<void> _pickRecent() async {
    final address = await showAddressPickerSheet(context);
    if (address != null && mounted) {
      _recipientController.text = address;
    }
  }

  void _review() => setState(() => _step = _Step.confirm);
  void _backToForm() => setState(() => _step = _Step.form);

  Future<void> _confirmSend() async {
    setState(() {
      _step = _Step.sending;
      _errorMessage = null;
    });
    try {
      final settings = SettingsService();
      final account = (await settings.getActiveRegularAccount())!;
      final submissionService = ref.read(transactionSubmissionServiceProvider);
      await submissionService.balanceTransfer(
        account,
        _recipientController.text.trim(),
        _amount,
        _networkFee,
        _blockHeight,
      );
      RecentAddressesService().addAddress(_recipientController.text.trim());
      if (mounted) setState(() => _step = _Step.complete);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.confirm;
          _errorMessage = 'Transfer failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final balance = ref.watch(effectiveMaxBalanceProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF3D3D3D)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: switch (_step) {
            _Step.form => _buildForm(colors, text, balance),
            _Step.confirm => _buildConfirm(colors, text),
            _Step.sending => _buildSending(colors, text),
            _Step.complete => _buildComplete(colors, text),
          },
        ),
      ),
    );
  }

  Widget _header(AppColorsV2 colors, AppTextTheme text, {VoidCallback? onBack}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (onBack != null)
          AppBackButton(onTap: onBack)
        else
          Text('Send', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.close, color: colors.textPrimary, size: 20),
        ),
      ],
    );
  }

  Widget _buildForm(AppColorsV2 colors, AppTextTheme text, AsyncValue<BigInt> balance) {
    final recipient = _recipientController.text.trim();
    final activeId = ref.watch(activeAccountProvider).value?.account.accountId ?? '';
    final amountStatus = SendScreenLogic.getAmountStatus(_amount, balance.value ?? BigInt.zero, _networkFee);
    final btnDisabled = SendScreenLogic.isButtonDisabled(
      hasAddressError: _hasAddressError,
      amountStatus: amountStatus,
      recipientText: recipient,
      activeAccountId: activeId,
      isFetchingFee: _isFetchingFee,
    );
    final btnText = SendScreenLogic.getButtonText(
      hasAddressError: _hasAddressError,
      amountStatus: amountStatus,
      recipientText: recipient,
      amount: _amount,
      activeAccountId: activeId,
      formattingService: _fmt,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(colors, text),
        const SizedBox(height: 40),
        Text('Send To', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 12),
        _addressInput(colors, text),
        const SizedBox(height: 12),
        Row(
          children: [
            _iconButton(Icons.qr_code_scanner, colors, _scanQr),
            const SizedBox(width: 8),
            _iconButton(Icons.history, colors, _pickRecent),
          ],
        ),
        const SizedBox(height: 40),
        _amountCard(colors, text, balance),
        const SizedBox(height: 12),
        _feeRow(colors, text),
        const SizedBox(height: 8),
        _actionButton(
          label: btnText,
          colors: colors,
          text: text,
          disabled: btnDisabled,
          onTap: btnDisabled ? null : _review,
        ),
      ],
    );
  }

  Widget _addressInput(AppColorsV2 colors, AppTextTheme text) {
    final hasRecipient = _recipientController.text.trim().isNotEmpty && !_hasAddressError;
    if (hasRecipient) {
      return GestureDetector(
        onTap: () => _recipientController.clear(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
          decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AddressFormattingService.formatAddress(
                  _recipientController.text.trim(),
                  prefix: 15,
                  ellipses: '.......',
                  postFix: 14,
                ),
                style: text.smallParagraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_recipientChecksum != null) ...[
                const SizedBox(height: 4),
                Text(_recipientChecksum!, style: text.smallParagraph?.copyWith(color: colors.accentPink)),
              ],
            ],
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(8)),
        child: TextField(
          controller: _recipientController,
          textAlignVertical: TextAlignVertical.center,
          style: text.smallParagraph?.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: 'Quan Address',
            hintStyle: text.smallParagraph?.copyWith(color: colors.textTertiary),
          ),
        ),
      ),
    );
  }

  Widget _amountCard(AppColorsV2 colors, AppTextTheme text, AsyncValue<BigInt> balance) {
    return SizedBox(
      height: 120,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 20,
            child: TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFilter()],
              style: text.mediumTitle?.copyWith(color: colors.textPrimary, fontSize: 32),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: '0 ${AppConstants.tokenSymbol}',
                hintStyle: text.mediumTitle?.copyWith(color: colors.textTertiary, fontSize: 32),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available: ${balance.when(data: (b) => _fmt.formatBalance(b), loading: () => '...', error: (_, _) => '0')} ${AppConstants.tokenSymbol}',
                  style: text.detail?.copyWith(color: colors.textSecondary),
                ),
                GestureDetector(
                  onTap: _hasAddressError ? null : _setMax,
                  child: Text('Max', style: text.detail?.copyWith(color: colors.textSecondary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(AppColorsV2 colors, AppTextTheme text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Network Fee:', style: text.detail?.copyWith(color: colors.textSecondary)),
        Text(
          _isFetchingFee ? '...' : '${_fmt.formatBalance(_networkFee)} ${AppConstants.tokenSymbol}',
          style: text.detail?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildConfirm(AppColorsV2 colors, AppTextTheme text) {
    final recipient = _recipientController.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(colors, text, onBack: _backToForm),
        const SizedBox(height: 72),
        Text(
          '${_fmt.formatBalance(_amount)} ${AppConstants.tokenSymbol}',
          style: text.mediumTitle?.copyWith(color: colors.textPrimary, fontSize: 32),
        ),
        const SizedBox(height: 64),
        Text(
          'To:',
          style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          AddressFormattingService.formatAddress(recipient, prefix: 15, ellipses: '.......', postFix: 14),
          style: text.smallParagraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
        ),
        if (_recipientChecksum != null) ...[
          const SizedBox(height: 4),
          Text(_recipientChecksum!, style: text.smallParagraph?.copyWith(color: colors.accentPink)),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: text.detail?.copyWith(color: colors.textError)),
        ],
        const SizedBox(height: 64),
        _feeRow(colors, text),
        const SizedBox(height: 8),
        _actionButton(label: 'Confirm', colors: colors, text: text, onTap: _confirmSend),
      ],
    );
  }

  Widget _buildSending(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(colors, text),
        const SizedBox(height: 80),
        CircularProgressIndicator(color: colors.textPrimary),
        const SizedBox(height: 24),
        Text('Sending...', style: text.smallTitle?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildComplete(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(colors, text),
        const SizedBox(height: 80),
        const SuccessCheck(size: 64),
        const SizedBox(height: 24),
        Text('Sent!', style: text.smallTitle?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          '${_fmt.formatBalance(_amount)} ${AppConstants.tokenSymbol}',
          style: text.paragraph?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 80),
        _actionButton(label: 'Done', colors: colors, text: text, onTap: () => Navigator.pop(context)),
      ],
    );
  }

  Widget _iconButton(IconData icon, AppColorsV2 colors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: GlassContainer(
          asset: GlassContainer.smallAsset,
          child: Icon(icon, color: colors.textPrimary, size: 20),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required AppColorsV2 colors,
    required AppTextTheme text,
    bool disabled = false,
    VoidCallback? onTap,
  }) {
    return Button(label: label, onTap: onTap, isDisabled: disabled, variant: ButtonVariant.secondary);
  }
}

void showSendSheetV2(BuildContext context, {String? address}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
    builder: (_) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SendSheet(initialAddress: address),
      ),
    ),
  );
}
