import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/propose/propose_amount_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ProposeRecipientScreen extends ConsumerStatefulWidget {
  final MultisigAccount msig;
  const ProposeRecipientScreen({super.key, required this.msig});

  @override
  ConsumerState<ProposeRecipientScreen> createState() => _ProposeRecipientScreenState();
}

class _ProposeRecipientScreenState extends ConsumerState<ProposeRecipientScreen> {
  final _recipientController = TextEditingController();
  final _recipientFocus = FocusNode();
  final Map<String, String> _checksums = {};
  List<String> _recents = [];
  bool _loadingRecents = true;
  bool _hasAddressError = true;
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
    _recipientFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final checksumService = ref.read(humanReadableChecksumServiceProvider);
    final recentService = ref.read(recentAddressesServiceProvider);
    try {
      final all = await recentService.getAddresses();
      final addresses = all.where((a) => a != widget.msig.accountId).toList();
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
      debugPrint('ProposeRecipientScreen recents error: $e');
      if (mounted) setState(() => _loadingRecents = false);
    }
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
    _lookup(text);
  }

  void _lookup(String address) {
    final substrate = ref.read(substrateServiceProvider);
    final checksumService = ref.read(humanReadableChecksumServiceProvider);
    final valid = substrate.isValidSS58Address(address);
    setState(() {
      _hasAddressError = !valid;
      _recipientChecksum = null;
    });
    if (valid) {
      checksumService.getHumanReadableName(address).then((c) {
        if (mounted) setState(() => _recipientChecksum = c);
      });
    }
  }

  bool get _canContinue {
    final text = _recipientController.text.trim();
    if (text.isEmpty || _hasAddressError) return false;
    if (text == widget.msig.accountId) return false;
    return true;
  }

  Future<void> _scanQr() async {
    final substrate = ref.read(substrateServiceProvider);
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => QrScannerPage(validator: (code) => substrate.isValidSS58Address(code)),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _recipientController.text = result);
  }

  void _continue() {
    if (!_canContinue) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProposeAmountScreen(
          msig: widget.msig,
          recipientAddress: _recipientController.text.trim(),
          recipientChecksum: _recipientChecksum,
        ),
      ),
    );
  }

  void _onRecentTap(String address) {
    _recipientController.text = address;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.multisigProposeTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.multisigProposeSelectRecipientTo,
            style: text.sendSectionLabel?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 12),
          _buildRecipientField(l10n, colors, text),
          const SizedBox(height: 28),
          _buildScanRow(l10n, colors, text),
          const SizedBox(height: 28),
          DottedBorder(
            dashLength: 3,
            gapLength: 5,
            color: colors.borderButton.useOpacity(0.5),
            child: const SizedBox(width: double.infinity, height: 1),
          ),
          const SizedBox(height: 28),
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
                      final addr = _recents[i];
                      final checksum = _checksums[addr];
                      final isLast = i == _recents.length - 1;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _onRecentTap(addr),
                              borderRadius: BorderRadius.circular(8),
                              child: checksum != null
                                  ? AddressCheckphraseWithInitial(recipientChecksum: checksum, recipientAddress: addr)
                                  : const Skeleton(height: 36),
                            ),
                          ),
                          if (!isLast) ...[
                            const SizedBox(height: 14),
                            Divider(height: 1, color: colors.txItemSeparator),
                            const SizedBox(height: 14),
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
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: _canContinue ? l10n.sendSelectRecipientContinue : l10n.sendEnterAddress,
          variant: ButtonVariant.primary,
          isDisabled: !_canContinue,
          onTap: _continue,
        ),
      ),
    );
  }

  Widget _buildRecipientField(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
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
                          autocorrect: false,
                          enableSuggestions: false,
                          style: text.smallParagraph?.copyWith(color: colors.textPrimary),
                          decoration: InputDecoration(
                            hintText: l10n.multisigProposeSearchHint(AppConstants.tokenSymbol),
                          ),
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

  Widget _buildScanRow(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _scanQr,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: colors.borderButton),
              ),
              child: Icon(Icons.qr_code_scanner, size: 24, color: colors.textPrimary),
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
}
