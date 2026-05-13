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

class ProposeDoneScreen extends ConsumerWidget {
  final MultisigAccount msig;
  final String recipientAddress;
  final String recipientChecksum;
  final BigInt amount;
  final int proposalId;
  final int myApprovalCount;
  final int currentBlock;

  const ProposeDoneScreen({
    super.key,
    required this.msig,
    required this.recipientAddress,
    required this.recipientChecksum,
    required this.amount,
    required this.proposalId,
    required this.myApprovalCount,
    required this.currentBlock,
  });

  void _popToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amountText = '${fmt.formatBalance(amount, maxDecimals: 4)} ${AppConstants.tokenSymbol}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popToHome(context);
      },
      child: ScaffoldBase(
        appBar: V2AppBar(title: 'Propose', leading: AppBackButton(onTap: () => _popToHome(context))),
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
                    'Proposal created',
                    textAlign: TextAlign.center,
                    style: text.largeTitle?.copyWith(fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Awaiting approvals from your co-signers.',
                    textAlign: TextAlign.center,
                    style: text.smallParagraph?.copyWith(color: colors.textTertiary),
                  ),
                  const SizedBox(height: 32),
                  Text(amountText, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('to $recipientChecksum', style: text.detail?.copyWith(color: colors.checksum)),
                  const SizedBox(height: 4),
                  Text(
                    AddressFormattingService.formatAddress(recipientAddress),
                    style: text.detail?.copyWith(color: colors.textTertiary, fontFamily: AppTextTheme.fontFamilySecondary),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: colors.surfaceDeep,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.borderButton.useOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fingerprint, size: 18, color: colors.checksum),
                        const SizedBox(width: 8),
                        Text(
                          'Signatures: $myApprovalCount/${msig.threshold}',
                          style: text.smallParagraph?.copyWith(color: colors.textPrimary),
                        ),
                      ],
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
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.success, width: 2)),
      alignment: Alignment.center,
      child: Icon(Icons.check, size: 32, color: colors.success),
    );
  }
}
