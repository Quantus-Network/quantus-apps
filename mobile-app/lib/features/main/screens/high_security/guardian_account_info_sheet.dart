import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class GuardianAccountInfoSheet extends StatefulWidget {
  const GuardianAccountInfoSheet({super.key});

  @override
  State<GuardianAccountInfoSheet> createState() =>
      _GuardianAccountInfoSheetState();
}

class _GuardianAccountInfoSheetState extends State<GuardianAccountInfoSheet> {
  void _closeSheet() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
        decoration: ShapeDecoration(
          color: context.themeColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(7),
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: _closeSheet,
                    child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: context.themeSize.infoSheetTitleIcon,
                ),
                const SizedBox(width: 22),
                Text(
                  'What is a Guardian Account',
                  style: context.themeText.largeTag,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'A Guardian account acts as a secure backstop. It intercepts transactions by diverting funds to itself if the Entrusted account (this account) is compromised. The Guardian account can be owned by you or a trusted 3rd party.',
              style: context.themeText.smallParagraph,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A Guardian account can:',
                    style: context.themeText.smallParagraph,
                  ),
                  Text(
                    '• Intercept any transaction',
                    style: context.themeText.smallParagraph,
                  ),
                  Text(
                    '• Pull all funds from this account',
                    style: context.themeText.smallParagraph,
                  ),
                  Text(
                    '• Change the recovery address',
                    style: context.themeText.smallParagraph,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The Guardian account should not be in the same wallet as the Entrusted account as in the case of theft both would be exposed.',
              style: context.themeText.smallParagraph,
            ),
            const SizedBox(height: 16),
            Text(
              'The harder the Guardian account is to access, the higher the security. An account on a cold storage wallet is the most secure.',
              style: context.themeText.smallParagraph,
            ),
            const SizedBox(height: 40),
            Button(
              variant: ButtonVariant.primary,
              label: 'Got it!',
              onPressed: () {
                _closeSheet();
              },
            ),
            SizedBox(height: context.themeSize.bottomButtonSpacing),
          ],
        ),
      ),
    );
  }
}

// Helper function to show the receive sheet
void showGuardianAccountInfoSheet(BuildContext context) {
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
                colors: [
                  Colors.black,
                  const Color(0xFF312E6E).useOpacity(0.4),
                  Colors.black,
                ],
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
              child: const GuardianAccountInfoSheet(),
            ),
          ),
        ),
      ],
    ),
  );
}
