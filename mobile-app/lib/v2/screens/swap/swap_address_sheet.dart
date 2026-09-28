import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_checkbox.dart';
import 'package:resonance_network_wallet/v2/screens/swap/saved_address_picker_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// Whether the external address receives the swapped funds or gets them back.
enum SwapAddressRole { recipient, refund }

/// Asks for the external address on [token]'s network, then [quote]s the swap
/// with it. Pops the quote, or null when dismissed.
Future<SwapQuote?> showSwapAddressSheet(
  BuildContext context, {
  required SwapToken token,
  required SwapAddressRole role,
  required Future<SwapQuote> Function(String address) quote,
}) {
  return BottomSheetContainer.show<SwapQuote>(
    context,
    builder: (_) => _SwapAddressSheet(token: token, role: role, quote: quote),
  );
}

class _SwapAddressSheet extends ConsumerStatefulWidget {
  final SwapToken token;
  final SwapAddressRole role;
  final Future<SwapQuote> Function(String address) quote;

  const _SwapAddressSheet({required this.token, required this.role, required this.quote});

  @override
  ConsumerState<_SwapAddressSheet> createState() => _SwapAddressSheetState();
}

class _SwapAddressSheetState extends ConsumerState<_SwapAddressSheet> {
  static const _addressBookAsset = 'assets/v2/swap_address_book.svg';
  static const _qrAsset = 'assets/v2/swap_qr_code.svg';
  static const _iconButtonSize = 32.0;

  final _controller = TextEditingController();
  bool _save = false;
  bool _quoting = false;

  String get _address => _controller.text.trim();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final navigator = Navigator.of(context);
    final address = _address;
    setState(() => _quoting = true);
    try {
      final quote = await widget.quote(address);
      if (_save) await ref.read(swapServiceProvider).saveAddress(widget.token.network, address);
      navigator.pop(quote);
    } catch (e) {
      quantusPrint('Swap quote failed: $e');
      if (!mounted) return;
      context.showErrorToaster(message: ref.read(l10nProvider).swapQuoteError(describeSwapError(e)));
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _fill(Future<String?> source) async {
    final address = await source;
    if (address != null && mounted) setState(() => _controller.text = address);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final token = widget.token;
    final recipient = widget.role == SwapAddressRole.recipient;

    return BottomSheetContainer(
      title: recipient ? l10n.swapRecipientAddressTitle : l10n.swapRefundAddressTitle,
      trailing: QuantusIconButton.ghost(
        icon: Icons.close,
        onTap: () => Navigator.pop(context),
        size: IconButtonSize.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(l10n.swapAddressLabel(token.symbol), style: text.headingRow.copyWith(color: colors.textContent)),
          const SizedBox(height: 12),
          QuantusTextField(
            controller: _controller,
            hint: l10n.swapAddressHint(token.networkName),
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            trailingWidth: _iconButtonSize * 2 + 12,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconButton(_addressBookAsset, () => _fill(showSavedAddressPickerSheet(context, token))),
                const SizedBox(width: 8),
                _iconButton(
                  _qrAsset,
                  () =>
                      _fill(Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QrScannerPage()))),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            recipient
                ? l10n.swapRecipientAddressNotice(token.symbol)
                : l10n.swapRefundAddressNotice(token.symbol, token.networkName),
            style: text.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 12),
          SettingsCheckbox(checked: _save, label: l10n.swapSaveAddress, onTap: () => setState(() => _save = !_save)),
          const SizedBox(height: 32),
          QuantusButton.simple(
            label: l10n.swapContinue,
            onTap: _continue,
            isDisabled: _address.isEmpty,
            isLoading: _quoting,
          ),
          const SizedBox(height: 4),
          QuantusButton.simple(
            label: l10n.commonCancel,
            variant: ButtonVariant.underline,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(String asset, VoidCallback onTap) {
    final colors = context.colorsV3;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _iconButtonSize,
        height: _iconButtonSize,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.bgVoid,
          borderRadius: context.radiusV3.smBorder,
          border: Border.all(color: colors.borderHairline),
        ),
        child: SvgPicture.asset(asset, colorFilter: ColorFilter.mode(colors.textContent, BlendMode.srcIn)),
      ),
    );
  }
}
