import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

class ErrorDisplay extends ConsumerStatefulWidget {
  final AsyncValue<Account?> activeAccountAsync;
  final Function(bool) setIsErrorSheetDisplayed;

  const ErrorDisplay({
    super.key,
    required this.activeAccountAsync,
    required this.setIsErrorSheetDisplayed,
  });

  @override
  ConsumerState<ErrorDisplay> createState() => _ErrorDisplayState();
}

class _ErrorDisplayState extends ConsumerState<ErrorDisplay> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: ShapeDecoration(
          color: context.themeColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              Icons.error_outline,
              color: context.themeColors.error,
              size: 50,
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to Connect',
              style: context.themeText.smallTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              widget.activeAccountAsync.error?.toString() ??
                  'Could not load wallet data. Please check your '
                      'network connection and try again.',
              style: context.themeText.detail?.copyWith(
                color: context.themeColors.textError,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            Button(
              variant: ButtonVariant.glassOutline,
              label: 'Retry',
              onPressed: () {
                widget.setIsErrorSheetDisplayed(false);

                ref.invalidate(activeAccountProvider);
                ref.invalidate(balanceProvider);
                ref.invalidate(activeAccountTransactionsProvider);
                
                Navigator.pop(context);
              },
            ),
            SizedBox(height: context.themeSize.bottomButtonSpacing),
          ],
        ),
      ),
    );
  }
}

void showErrorDisplaySheet(
  BuildContext context, {
  required AsyncValue<Account?> activeAccountAsync,
  required Function(bool) setIsErrorSheetDisplayed,
}) {
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
              child: ErrorDisplay(
                activeAccountAsync: activeAccountAsync,
                setIsErrorSheetDisplayed: setIsErrorSheetDisplayed,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
