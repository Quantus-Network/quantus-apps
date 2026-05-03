import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class PullFundsConfirmationSheet extends ConsumerStatefulWidget {
  final String lostAccountAddress;
  final Account guardianAccount;
  final VoidCallback onConfirm;

  const PullFundsConfirmationSheet({
    super.key,
    required this.lostAccountAddress,
    required this.guardianAccount,
    required this.onConfirm,
  });

  @override
  ConsumerState<PullFundsConfirmationSheet> createState() => _PullFundsConfirmationSheetState();
}

class _PullFundsConfirmationSheetState extends ConsumerState<PullFundsConfirmationSheet> {
  BigInt? _fee;
  BigInt? _guardianBalance;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _calculateFeeAndBalance();
  }

  Future<void> _calculateFeeAndBalance() async {
    try {
      final highSecurityService = ref.read(highSecurityServiceProvider);
      final substrateService = ref.read(substrateServiceProvider);

      // Run both fetch operations in parallel
      final results = await Future.wait([
        highSecurityService.getPullAllFundsFee(widget.lostAccountAddress, widget.guardianAccount),
        substrateService.queryBalance(widget.guardianAccount.accountId),
      ]);

      if (mounted) {
        setState(() {
          _fee = (results[0] as ExtrinsicFeeData).fee;
          _guardianBalance = results[1] as BigInt;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool get _canProceed {
    if (_fee == null || _guardianBalance == null) return false;
    return _guardianBalance! >= _fee!;
  }

  @override
  Widget build(BuildContext context) {
    final formattingService = ref.watch(numberFormattingServiceProvider);

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
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 69),
            Text(
              'Are you sure you want to pull all funds from the high security account into the guardian account?',
              textAlign: TextAlign.center,
              style: context.themeText.smallTitle,
            ),
            const SizedBox(height: 48),
            if (_isLoading)
              CircularProgressIndicator(color: context.themeColors.background, strokeWidth: 2.0)
            else if (_error != null)
              Text(
                'Error calculating fee: $_error',
                textAlign: TextAlign.center,
                style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
              )
            else
              Column(
                children: [
                  Text(
                    'Fee: ${formattingService.formatBalance(_fee!)} ${AppConstants.tokenSymbol}',
                    textAlign: TextAlign.center,
                    style: context.themeText.smallTitle,
                  ),
                  if (!_canProceed) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Insufficient funds in guardian account',
                      textAlign: TextAlign.center,
                      style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 44),
            Row(
              spacing: context.themeSize.buttonsHorizontalSpacing,
              children: [
                Expanded(
                  child: Button(
                    variant: ButtonVariant.danger,
                    label: 'Confirm',
                    textStyle: context.themeText.smallParagraph?.copyWith(fontWeight: FontWeight.w600),
                    isDisabled: _isLoading || !_canProceed,
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onConfirm();
                    },
                  ),
                ),
                Expanded(
                  child: Button(
                    variant: ButtonVariant.neutral,
                    label: 'Cancel',
                    textStyle: context.themeText.smallParagraph?.copyWith(fontWeight: FontWeight.w600),
                    onPressed: () => Navigator.pop(context),
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

void showPullFundsConfirmationSheet(
  BuildContext context,
  String lostAccountAddress,
  Account guardianAccount,
  VoidCallback onConfirm,
) {
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
            child: Container(
              color: Colors.black.useOpacity(0.3),
              child: PullFundsConfirmationSheet(
                lostAccountAddress: lostAccountAddress,
                guardianAccount: guardianAccount,
                onConfirm: onConfirm,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
