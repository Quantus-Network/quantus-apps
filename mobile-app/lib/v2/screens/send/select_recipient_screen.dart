import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/address_input_field.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/private_activity_notice.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class SelectRecipientScreen extends ConsumerStatefulWidget {
  final SendStrategy strategy;

  const SelectRecipientScreen({super.key, required this.strategy});

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
  bool _canContinue = false;
  bool _isSelfSend = false;
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
    final recentAddressesService = ref.read(recentAddressesServiceProvider);

    try {
      final all = await recentAddressesService.getAddresses();
      final currentId = widget.strategy.sourceAccountId(ref);
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
      quantusPrint('SelectRecipientScreen recents: $e');
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
        _canContinue = false;
        _isSelfSend = false;
      });
      return;
    }
    _lookupAddress(text);
  }

  void _lookupAddress(String address) {
    final checksumService = ref.read(humanReadableChecksumServiceProvider);
    final substrate = ref.read(substrateServiceProvider);
    final isValid = substrate.isValidSS58Address(address);
    final wasSelfSend = _isSelfSend;
    setState(() {
      _hasAddressError = !isValid;
      _isSelfSend = false;
      _recipientChecksum = null;
      _canContinue = false;
    });
    if (!isValid) return;
    // Async: encrypted sends check the address against every derived wormhole
    // address, not just the account id. Continue stays disabled until resolved.
    widget.strategy
        .isSelfRecipient(ref, address)
        .then((isSelf) {
          if (!mounted || _recipientController.text.trim() != address) return;
          setState(() {
            _isSelfSend = isSelf;
            _canContinue = !isSelf;
          });
          if (isSelf && !wasSelfSend) {
            context.showWarningToaster(message: ref.read(l10nProvider).sendLogicCantSelfTransfer);
          }
        })
        .catchError((Object e) {
          // Fail closed: without a verdict the send can't proceed anyway.
          quantusPrint('SelectRecipientScreen self-send check: $e');
        });
    checksumService.getHumanReadableName(address).then((checksum) {
      if (mounted) setState(() => _recipientChecksum = checksum);
    });
  }

  /// Single entry point for every way a recipient is supplied (scan, paste,
  /// recent). The controller text is assigned last and outside [setState] so the
  /// [_onRecipientChanged] listener drives validation and the continue button.
  void _setRecipient(String address, {String amount = '', bool isPayMode = false}) {
    _amountController.text = amount;
    setState(() => _isPayMode = isPayMode);
    _recipientController.text = address;
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
      _setRecipient(payment.to, amount: payment.amount, isPayMode: true);
    } else {
      _setRecipient(scanResult);
    }
  }

  void _continue() {
    if (!_canContinue) return;

    final address = _recipientController.text.trim();
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: inputAmountScreenRouteSettings,
        builder: (_) => InputAmountScreen(
          strategy: widget.strategy,
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
        _canContinue = false;
        _isSelfSend = false;
      });
    });
  }

  void _onRecentTap(String address) => _setRecipient(address);

  Future<void> _pasteRecipient() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _setRecipient(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final strings = widget.strategy.strings(l10n);
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      key: const Key(E2EKeys.sendSelectRecipientScreen),
      appBar: V2AppBar(title: strings.flowTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings.recipientSectionLabel, style: text.sendSectionLabel?.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 12),
              _buildRecipientField(colors, l10n),
              const SizedBox(height: 28),
              _buildScanRow(colors, text, l10n),
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
                    child: Text(
                      l10n.sendSelectRecipientRecents,
                      style: text.smallTitle?.copyWith(color: colors.textPrimary),
                    ),
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
      bottomContent: _buildBottomButton(l10n),
    );
  }

  Widget _buildRecipientField(AppColorsV2 colors, AppLocalizations l10n) {
    final hasValid = _recipientController.text.trim().isNotEmpty && !_hasAddressError;

    return AddressInputField(
      controller: _recipientController,
      focusNode: _recipientFocus,
      fieldKey: const Key(E2EKeys.sendRecipientField),
      hasValid: hasValid,
      recipientChecksum: _recipientChecksum,
      hintText: l10n.sendSelectRecipientSearchHint(AppConstants.tokenSymbol),
      trailing: IconButton(
        onPressed: _pasteRecipient,
        icon: const Icon(Icons.paste),
        iconSize: 20,
        color: colors.textPrimary,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
    );
  }

  Widget _buildScanRow(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
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
                  Text(l10n.sendSelectRecipientScanTitle, style: text.paragraph?.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.sendSelectRecipientScanSubtitle(AppConstants.tokenSymbol),
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

  Widget _buildBottomButton(AppLocalizations l10n) {
    final btnText = _canContinue
        ? l10n.sendSelectRecipientContinue
        : _isSelfSend
        ? l10n.sendLogicCantSelfTransfer
        : l10n.sendEnterAddress;

    final button = QuantusButton.simple(
      key: const Key(E2EKeys.sendContinueButton),
      label: btnText,
      variant: ButtonVariant.primary,
      isDisabled: !_canContinue,
      onTap: _continue,
    );

    if (!widget.strategy.showPrivateSendNotice) {
      return ScaffoldBaseBottomContent(child: button);
    }

    return ScaffoldBaseBottomContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrivateActivityNotice(title: l10n.privateSendTitle, subtitle: l10n.privateSendSubtitle),
          const SizedBox(height: 32),
          button,
        ],
      ),
    );
  }
}
