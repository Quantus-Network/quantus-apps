import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';

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
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return BottomSheetContainer(
      title: l10n.swapRefundPickerTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(widget.network, style: text.caption.copyWith(color: colors.textMuted)),
          ),
          const SizedBox(height: 24),
          if (_addresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(l10n.swapRefundPickerEmpty, style: text.caption.copyWith(color: colors.textMuted)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _addresses.length,
                separatorBuilder: (_, _) => const MenuDivider(),
                itemBuilder: (_, i) => _addressItem(_addresses[i], colors, text),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addressItem(String address, AppColorsV3 colors, AppTextThemeV3 text) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, address),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          AddressFormattingService.formatAddress(address),
          style: text.dataAddress.copyWith(color: colors.textContent),
        ),
      ),
    );
  }
}
