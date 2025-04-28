import 'package:flutter/material.dart';

class GradientActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final EdgeInsets padding;
  final Gradient gradient;
  final Color loadingIndicatorColor;
  final Color textColor;
  final double fontSize;
  final String fontFamily;
  final FontWeight fontWeight;

  const GradientActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.width = double.infinity, // Default to full width
    this.padding = const EdgeInsets.all(16),
    // Default gradient matching ImportWalletScreen
    this.gradient = const LinearGradient(
      begin: Alignment(0.50, 0.00),
      end: Alignment(0.50, 1.00),
      colors: [Color(0xFF0CE6ED), Color(0xFF8AF9A8)],
    ),
    this.loadingIndicatorColor = const Color(0xFF0E0E0E), // Dark indicator
    this.textColor = const Color(0xFF0E0E0E), // Dark text
    this.fontSize = 18,
    this.fontFamily = 'Fira Code',
    this.fontWeight = FontWeight.w500,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    return GestureDetector(
      // Disable onTap if loading or onPressed is null
      onTap: isDisabled ? null : onPressed,
      child: Opacity(
        // Dim if disabled
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          width: width,
          padding: padding,
          decoration: ShapeDecoration(
            // Use the provided gradient
            gradient: gradient,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: fontSize + 6, // Size indicator relative to font size
                    height: fontSize + 6,
                    child: CircularProgressIndicator(
                      color: loadingIndicatorColor,
                      strokeWidth: 2.0,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: fontSize,
                      fontFamily: fontFamily,
                      fontWeight: fontWeight,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
