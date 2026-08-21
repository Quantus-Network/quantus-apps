import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

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
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: hasValid,
          child: Opacity(
            opacity: hasValid ? 0 : 1,
            child: QuantusTextField(
              key: fieldKey,
              controller: controller,
              focusNode: focusNode,
              hint: hintText,
              trailing: trailing,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  borderRadius: context.radiusV3.mdBorder,
                  border: Border.all(color: colors.borderHairline),
                ),
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
                      style: text.dataAddressLarge.copyWith(color: colors.textContent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipientChecksum != null)
                      Text(recipientChecksum!, style: text.body.copyWith(color: colors.semanticLilac)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
