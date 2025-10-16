import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/label.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class CustomTextField extends StatelessWidget {
  final String? labelText;
  final TextStyle? textStyle;
  final String? initialValue;
  final Color? fillColor;
  final String? hintText;
  final TextStyle? hintStyle;
  final Icon? icon;
  final Widget? trailing;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final String? errorMsg;
  final double? leftPadding;
  final bool? disabled;

  const CustomTextField({
    super.key,
    this.labelText,
    this.textStyle,
    this.initialValue,
    this.fillColor,
    this.hintText,
    this.hintStyle,
    this.icon,
    this.trailing,
    this.obscureText = false,
    this.errorMsg,
    this.onChanged,
    this.leftPadding,
    this.controller,
    this.disabled = false,
  }) : assert(
         initialValue == null || controller == null,
         'Cannot provide both an initialValue and a controller.',
       );

  @override
  Widget build(BuildContext context) {
    // The main container for the entire widget
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min, // Takes up minimum vertical space
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The label is now optional and will only be displayed if labelText is not null.
          if (labelText != null) ...[
            Label(labelText!),
            const SizedBox(height: 4),
          ],
          // The container that forms the background of the input field
          Stack(
            alignment: AlignmentGeometry.center,
            children: [
              TextFormField(
                controller: controller,
                initialValue: initialValue,
                enabled: disabled != true,
                onChanged: onChanged,
                obscureText: obscureText,
                // Styling for the text inside the input field
                style: textStyle ?? context.themeText.smallTitle,
                decoration: InputDecoration(
                  fillColor: fillColor,
                  isDense: true, // Reduces vertical padding
                  enabledBorder: errorMsg != null
                      ? const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        )
                      : InputBorder.none,
                  focusedBorder: errorMsg != null
                      ? const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        )
                      : InputBorder.none,
                  contentPadding: EdgeInsets.only(
                    top: 10,
                    bottom: 10,
                    left: leftPadding ?? 11,
                    right: (trailing != null || icon != null) ? 40 : 11,
                  ), // Removes default padding
                  hintText: hintText,
                  // Style for the hint text when the field is empty
                  hintStyle:
                      hintStyle ??
                      context.themeText.smallTitle?.copyWith(
                        color: context.themeColors.textPrimary.useOpacity(0.5),
                      ),
                ),
              ),

              if (icon != null) Positioned(right: 16, child: icon!),
              if (trailing != null) Positioned(right: 10, child: trailing!),
            ],
          ),

          if (errorMsg != null) ...[
            const SizedBox(height: 4),
            Text(
              errorMsg!,
              style: context.themeText.tiny?.copyWith(
                color: context.themeColors.textError,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
