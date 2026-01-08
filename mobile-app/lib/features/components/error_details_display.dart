import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/copy_icon.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class ErrorDetailsButton extends StatelessWidget {
  final String error;
  final String? label;
  final IconData? icon;

  const ErrorDetailsButton({super.key, required this.error, this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showErrorDetailsActionSheet(context, error),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.themeColors.buttonGlass,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.themeColors.borderLight, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? Icons.error_outline, color: context.themeColors.textError, size: context.isTablet ? 20 : 18),
            const SizedBox(width: 8),
            Text(
              label ?? 'View Error Details',
              style: context.themeText.detail?.copyWith(color: context.themeColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorDetailsSheet extends StatefulWidget {
  final String error;

  const ErrorDetailsSheet({super.key, required this.error});

  @override
  State<ErrorDetailsSheet> createState() => _ErrorDetailsSheetState();
}

class _ErrorDetailsSheetState extends State<ErrorDetailsSheet> {
  bool _copied = false;

  void _closeSheet(BuildContext context) {
    Navigator.of(context).pop();
  }

  void _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.error));
    setState(() {
      _copied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: ShapeDecoration(
          color: context.themeColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header with close button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(7),
              decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () => _closeSheet(context),
                    child: Icon(Icons.close, size: context.isTablet ? 28 : 24, color: context.themeColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Title with error icon
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: context.themeColors.textError, size: context.isTablet ? 36 : 32),
                const SizedBox(width: 12),
                Text('Error Details', style: context.themeText.largeTitle),
              ],
            ),
            SizedBox(height: context.isTablet ? 36 : 28),

            // Error content container
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.themeColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.themeColors.borderLight, width: 1),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.error,
                  style: context.themeText.smallParagraph?.copyWith(
                    color: context.themeColors.textPrimary,
                    fontFamily: 'Fira Code',
                    height: 1.5,
                  ),
                ),
              ),
            ),

            SizedBox(height: context.isTablet ? 24 : 20),

            // Action buttons
            Column(
              children: [
                InkWell(
                  onTap: () => _copyToClipboard(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _copied
                          ? context.themeColors.buttonSuccess.useOpacity(0.2)
                          : context.themeColors.buttonGlass,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _copied ? context.themeColors.buttonSuccess : context.themeColors.borderLight,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_copied)
                          Icon(Icons.check, size: context.isTablet ? 20 : 18, color: context.themeColors.buttonSuccess)
                        else
                          CopyIcon(color: context.themeColors.textPrimary),
                        const SizedBox(width: 8),
                        Text(
                          _copied ? 'Copied!' : 'Copy Error',
                          style: context.themeText.paragraph?.copyWith(
                            color: _copied ? context.themeColors.buttonSuccess : context.themeColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Button(variant: ButtonVariant.neutral, label: 'Close', onPressed: () => _closeSheet(context)),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

void showErrorDetailsActionSheet(BuildContext context, String error) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, const Color(0xFF312E6E).useOpacity(0.4), Colors.black],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.black.useOpacity(0.3),
              child: ErrorDetailsSheet(error: error),
            ),
          ),
        ),
      ],
    ),
  );
}
