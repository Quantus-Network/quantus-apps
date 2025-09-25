import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/label.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class CustomTextField extends StatelessWidget {
  final String? labelText;
  final TextStyle? textStyle;
  final String? initialValue;
  final String? hintText;
  final TextStyle? hintStyle;
  final Icon? icon;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool hasError;
  final double? leftPadding;

  const CustomTextField({
    super.key,
    this.labelText,
    this.textStyle,
    this.initialValue,
    this.hintText,
    this.hintStyle,
    this.icon,
    this.obscureText = false,
    this.hasError = false,
    this.onChanged,
    this.leftPadding,
    this.controller,
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
              if (icon != null) Positioned(right: 16, child: icon!),

              TextFormField(
                controller: controller,
                initialValue: initialValue,
                onChanged: onChanged,
                obscureText: obscureText,
                // Styling for the text inside the input field
                style: textStyle ?? context.themeText.smallTitle,
                decoration: InputDecoration(
                  isDense: true, // Reduces vertical padding
                  enabledBorder: hasError
                      ? const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        )
                      : InputBorder.none,
                  focusedBorder: hasError
                      ? const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 1),
                        )
                      : InputBorder.none,
                  contentPadding: EdgeInsets.only(
                    top: 10,
                    bottom: 10,
                    left: leftPadding ?? 11,
                    right: icon != null ? 40 : 11,
                  ), // Removes default padding
                  hintText: hintText,
                  // Style for the hint text when the field is empty
                  hintStyle: hintStyle ?? context.themeText.smallTitle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
