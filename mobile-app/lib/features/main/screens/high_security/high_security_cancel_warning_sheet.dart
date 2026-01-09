import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class HighSecurityCancelWarningSheet extends StatefulWidget {
  const HighSecurityCancelWarningSheet({super.key});

  @override
  State<HighSecurityCancelWarningSheet> createState() => _HighSecurityCancelWarningSheetState();
}

class _HighSecurityCancelWarningSheetState extends State<HighSecurityCancelWarningSheet> {
  void _returnToAccountSetting() {
    if (!mounted) return;
    Navigator.of(context).popUntil(ModalRoute.withName(AppConstants.accountSettingsRouteName));
  }

  void _continueSetup() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
        decoration: ShapeDecoration(
          color: context.themeColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(7),
              decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: _continueSetup,
                    child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 69),
            Text(
              'Are you sure you want to exit High Security Setup?',
              textAlign: TextAlign.center,
              style: context.themeText.smallTitle,
            ),
            const SizedBox(height: 16),
            Text(
              'Your preferences will be discarded',
              textAlign: TextAlign.center,
              style: context.themeText.smallTitle,
            ),
            const SizedBox(height: 69),
            Row(
              spacing: context.themeSize.buttonsHorizontalSpacing,
              children: [
                Expanded(
                  child: Button(
                    variant: ButtonVariant.danger,
                    label: 'Exit anyway',
                    textStyle: context.themeText.smallParagraph?.copyWith(fontWeight: FontWeight.w600),
                    onPressed: () {
                      _returnToAccountSetting();
                    },
                  ),
                ),
                Expanded(
                  child: Button(
                    variant: ButtonVariant.neutral,
                    label: 'Continue',
                    textStyle: context.themeText.smallParagraph?.copyWith(fontWeight: FontWeight.w600),
                    onPressed: _continueSetup,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.themeSize.bottomButtonSpacing),
          ],
        ),
      ),
    );
  }
}

void showHighSecurityCancelWarningSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width, // Ensure full width
    ),
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
            child: Container(color: Colors.black.useOpacity(0.3), child: const HighSecurityCancelWarningSheet()),
          ),
        ),
      ],
    ),
  );
}
