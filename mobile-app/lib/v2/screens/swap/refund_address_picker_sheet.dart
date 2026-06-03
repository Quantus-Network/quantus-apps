import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

Future<String?> showRefundAddressPickerSheet(BuildContext context, String network) {
  return BottomSheetContainer.show<String>(context, builder: (_) => _RefundAddressPickerContent(network: network));
}

class _RefundAddressPickerContent extends ConsumerStatefulWidget {
  final String network;
  const _RefundAddressPickerContent({required this.network});

  @override
  ConsumerState<_RefundAddressPickerContent> createState() => _RefundAddressPickerContentState();
}

class _RefundAddressPickerContentState extends ConsumerState<_RefundAddressPickerContent> {
  List<String> _addresses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final addresses = await SwapService().getRefundAddresses(widget.network);
    if (mounted) setState(() => _addresses = addresses);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    return BottomSheetContainer(
      title: l10n.swapRefundPickerTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.network, style: text.detail?.copyWith(color: colors.textSecondary)),
          ),
          const SizedBox(height: 24),
          if (_addresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(l10n.swapRefundPickerEmpty, style: text.detail?.copyWith(color: colors.textTertiary)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _addresses.length,
                separatorBuilder: (_, _) => Divider(color: colors.separator, height: 1),
                itemBuilder: (_, i) => _addressItem(_addresses[i], colors, text),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addressItem(String address, AppColorsV2 colors, AppTextTheme text) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, address),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          AddressFormattingService.formatAddress(address),
          style: text.smallParagraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
