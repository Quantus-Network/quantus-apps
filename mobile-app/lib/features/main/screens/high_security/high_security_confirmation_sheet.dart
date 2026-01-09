import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/high_security_cancel_warning_sheet.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/high_security_created_sheet.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/high_security_form_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class HighSecurityConfirmationSheet extends ConsumerStatefulWidget {
  const HighSecurityConfirmationSheet({super.key});

  @override
  ConsumerState<HighSecurityConfirmationSheet> createState() => _HighSecurityConfirmationSheetState();
}

class _HighSecurityConfirmationSheetState extends ConsumerState<HighSecurityConfirmationSheet> {
  final HighSecurityService _highSecurityService = HighSecurityService();
  final SettingsService _settingsService = SettingsService();

  BigInt? _networkFee;
  bool _isSubmitting = false;

  void _confirmSetup() async {
    setState(() {
      _isSubmitting = true;
    });

    final formData = ref.read(highSecurityFormProvider);
    final activeAccount = (await _settingsService.getActiveAccount())!;

    await _highSecurityService.setupHighSecurityAccount(activeAccount, formData);

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      showHighSecurityCreatedSheet(context);
    }
  }

  void _cancelSetup() {
    showHighSecurityCancelWarningSheet(context);
  }

  void _fetchNetworkFee() async {
    final activeAccount = (await _settingsService.getActiveAccount())!;
    final formData = ref.read(highSecurityFormProvider);

    final fee = await _highSecurityService.getHighSecuritySetupFee(activeAccount, formData);

    setState(() {
      _networkFee = fee.fee;
    });
  }

  @override
  void initState() {
    super.initState();

    _fetchNetworkFee();
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(7),
              decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: _cancelSetup,
                    child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('WARNING:', style: context.themeText.largeTitle?.copyWith(color: context.themeColors.buttonDanger)),
            const SizedBox(height: 11),
            Text(
              'These features are designed to help keep your funds safer, but once confirmed this account CANNOT:',
              style: context.themeText.largeTag,
            ),
            const SizedBox(height: 11),
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Turn off High Security', style: context.themeText.smallParagraph),
                  Text('• Reverse a transaction', style: context.themeText.smallParagraph),
                  Text('• Change the Guardian account', style: context.themeText.smallParagraph),
                  Text('• Change the Recovery account', style: context.themeText.smallParagraph),
                  Text('• Change the Safeguard window', style: context.themeText.smallParagraph),
                  Text('• Deny a recovery request', style: context.themeText.smallParagraph),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Text(
              'You will still be able to send and receive crypto and view requests.',
              style: context.themeText.smallParagraph,
            ),
            const SizedBox(height: 116),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Network Fee', style: context.themeText.detail?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${_networkFee ?? 'Fetching...'} ${AppConstants.tokenSymbol}',
                  style: context.themeText.detail?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Button(
              isLoading: _isSubmitting,
              variant: ButtonVariant.primary,
              label: 'Confirm',
              onPressed: () {
                _confirmSetup();
              },
            ),
            const SizedBox(height: 13),
            Button(
              isDisabled: _isSubmitting,
              variant: ButtonVariant.dangerOutline,
              label: 'Cancel',
              onPressed: () {
                _cancelSetup();
              },
            ),
            SizedBox(height: context.themeSize.bottomButtonSpacing),
          ],
        ),
      ),
    );
  }
}

void showHighSecurityConfirmationSheet(BuildContext context) {
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
            child: Container(color: Colors.black.useOpacity(0.3), child: const HighSecurityConfirmationSheet()),
          ),
        ),
      ],
    ),
  );
}
