import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class HighSecurityCreatedSheet extends StatefulWidget {
  const HighSecurityCreatedSheet({super.key});

  @override
  State<HighSecurityCreatedSheet> createState() =>
      _HighSecurityCreatedSheetState();
}

class _HighSecurityCreatedSheetState extends State<HighSecurityCreatedSheet> {
  void _returnToAccountSetting() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).popUntil(ModalRoute.withName(AppConstants.accountSettingsRouteName));
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
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: _returnToAccountSetting,
                    child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 69),
            SvgPicture.asset('assets/logo/logo.svg', width: 91, height: 85),
            const SizedBox(height: 18),
            Text('CONFIRMED', style: context.themeText.largeTitle),
            const SizedBox(height: 46),
            Text(
              'High Security has been successfully setup on this account',
              style: context.themeText.largeTag,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 46),
            Button(
              variant: ButtonVariant.neutral,
              label: 'Done',
              width: 188,
              onPressed: _returnToAccountSetting,
            ),
            SizedBox(height: context.themeSize.bottomButtonSpacing),
          ],
        ),
      ),
    );
  }
}

void showHighSecurityCreatedSheet(BuildContext context) {
  void returnToAccountSetting() {
    Navigator.of(
      context,
    ).popUntil(ModalRoute.withName(AppConstants.accountSettingsRouteName));
  }

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
              child: const HighSecurityCreatedSheet(),
            ),
          ),
        ),
      ],
    ),
  ).whenComplete(() {
    returnToAccountSetting();
  });
}
