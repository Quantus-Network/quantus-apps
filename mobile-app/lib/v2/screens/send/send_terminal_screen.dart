import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/explorer_link.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Shared success screen for both regular sends and multisig proposals,
/// configured entirely by [SendTerminalContent].
class SendTerminalScreen extends ConsumerWidget {
  final SendTerminalContent content;

  const SendTerminalScreen({super.key, required this.content});

  void _popToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final shortAddr = AddressFormattingService.formatAddress(content.recipientAddress.trim());
    final checksum = content.recipientChecksum;
    final signaturesLabel = content.signaturesLabel;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _popToHome(context);
      },
      child: ScaffoldBase(
        key: const Key(E2EKeys.sendTxSubmittedScreen),
        appBar: V2AppBar(
          title: content.title,
          leading: AppBackButton(onTap: () => _popToHome(context)),
        ),
        mainContent: Column(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (content.topSpacing > 0) SizedBox(height: content.topSpacing),
                  _successMark(colors),
                  const SizedBox(height: 32),
                  Text(
                    content.headline,
                    textAlign: TextAlign.center,
                    style: text.largeTitle?.copyWith(fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content.subline,
                    textAlign: TextAlign.center,
                    style: text.smallParagraph?.copyWith(color: colors.textTertiary, letterSpacing: 0.74),
                  ),
                  const SizedBox(height: 32),
                  if (content.amountText != null) ...[
                    Text(content.amountText!, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
                    const SizedBox(height: 16),
                  ],
                  Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      style: text.paragraph?.copyWith(color: colors.textPrimary),
                      children: [
                        TextSpan(
                          text: l10n.sendTxSubmittedToLabel,
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
                  if (checksum != null && checksum.isNotEmpty) ...[
                    Text(
                      checksum,
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
                  if (signaturesLabel != null) ...[
                    const SizedBox(height: 32),
                    _signaturesChip(colors, text, signaturesLabel),
                  ],
                ],
              ),
            ),
            if (content.explorerUrl != null) ...[
              const Spacer(),
              Center(child: ExplorerLink(url: content.explorerUrl)),
              const SizedBox(height: 8),
            ],
          ],
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: QuantusButton.simple(
            key: const Key(E2EKeys.sendTxSubmittedDoneButton),
            label: content.doneLabel,
            variant: ButtonVariant.primary,
            onTap: () => _popToHome(context),
          ),
        ),
      ),
    );
  }

  Widget _signaturesChip(AppColorsV2 colors, AppTextTheme text, String label) {
    return Container(
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
          Text(label, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _successMark(AppColorsV2 colors) {
    const size = 78.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.success, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check, size: 32, color: colors.success),
    );
  }
}
