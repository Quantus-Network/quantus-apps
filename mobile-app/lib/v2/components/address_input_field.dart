import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Dual-state address input shared by every flow where the user enters a
/// destination address (send, redeem, ...). When the controller holds a valid
/// SS58 address (`hasValid`) it shows a pill with the truncated address and the
/// optional human checksum; otherwise it shows an editable field with an
/// optional [trailing] action (e.g. a paste button). Tapping the pill clears
/// the field and refocuses it for re-entry.
class AddressInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasValid;
  final String? recipientChecksum;
  final String hintText;
  final Widget? trailing;
  final int addressPrefix;
  final int addressPostfix;
  final Key? fieldKey;

  const AddressInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasValid,
    required this.recipientChecksum,
    required this.hintText,
    this.trailing,
    this.addressPrefix = 16,
    this.addressPostfix = 16,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

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
                      Expanded(
                        child: TextField(
                          key: fieldKey,
                          controller: controller,
                          focusNode: focusNode,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          textCapitalization: TextCapitalization.none,
                          scrollPadding: const EdgeInsets.only(bottom: 120),
                          style: text.smallParagraph?.copyWith(color: colors.textPrimary),
                          decoration: InputDecoration(hintText: hintText),
                        ),
                      ),
                      ?trailing,
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
                  controller.clear();
                  focusNode.requestFocus();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: colors.toasterBackground, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AddressFormattingService.formatAddress(
                          controller.text.trim(),
                          prefix: addressPrefix,
                          postFix: addressPostfix,
                        ),
                        style: text.smallParagraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (recipientChecksum != null)
                        Text(recipientChecksum!, style: text.detail?.copyWith(color: colors.checksum)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
