import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class TxSubmittedScreen extends ConsumerWidget {
  final BigInt amount;
  final String recipientAddress;
  final String? recipientChecksum;
  final bool isPayMode;

  const TxSubmittedScreen({
    super.key,
    required this.amount,
    required this.recipientAddress,
    this.recipientChecksum,
    this.isPayMode = false,
  });

  void _popToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
  }

  String _headline(WidgetRef ref) {
    final formattingService = ref.watch(numberFormattingServiceProvider);
    final n = formattingService.formatBalance(amount, maxDecimals: 4);
    final action = isPayMode ? 'paid' : 'sent';
    return '$n ${AppConstants.tokenSymbol} $action';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
    final addr = recipientAddress.trim();
    final shortAddr = AddressFormattingService.formatAddress(addr);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _popToHome(context);
      },
      child: ScaffoldBase(
        appBar: V2AppBar(
          title: isPayMode ? 'Pay' : 'Send',
          leading: AppBackButton(onTap: () => _popToHome(context)),
        ),
        mainContent: Column(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 70),
                  _successMark(colors),
                  const SizedBox(height: 32),
                  Text(
                    _headline(ref),
                    textAlign: TextAlign.center,
                    style: text.largeTitle?.copyWith(fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'On its way',
                    textAlign: TextAlign.center,
                    style: text.smallParagraph?.copyWith(color: colors.textTertiary, letterSpacing: 0.74),
                  ),
                  const SizedBox(height: 32),
                  Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      style: text.paragraph?.copyWith(color: colors.textPrimary),
                      children: [
                        TextSpan(
                          text: 'To',
                          style: text.paragraph?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        TextSpan(
                          text: ':',
                          style: text.paragraph?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (recipientChecksum != null && recipientChecksum!.isNotEmpty) ...[
                    Text(
                      recipientChecksum!,
                      textAlign: TextAlign.center,
                      style: text.smallParagraph?.copyWith(color: colors.checksum, height: 1.0),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    shortAddr,
                    textAlign: TextAlign.center,
                    style: text.smallParagraph?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontFamily: AppTextTheme.fontFamilySecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: QuantusButton.simple(label: 'Done', variant: ButtonVariant.primary, onTap: () => _popToHome(context)),
        ),
      ),
    );
  }

  Widget _successMark(AppColorsV2 colors) {
    final containerSize = 78.0;
    final iconSize = 32.0;

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.success, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check, size: iconSize, color: colors.success),
    );
  }
}
