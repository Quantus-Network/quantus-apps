import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/explorer_link.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

/// Shared success screen for both regular sends and multisig proposals,
/// configured entirely by [SendTerminalContent].
class SendTerminalScreen extends ConsumerWidget {
  final SendTerminalContent content;

  const SendTerminalScreen({super.key, required this.content});

  static const _successRingSize = 78.0;
  static const _checkIconSize = 32.0;
  static const _borderWidth = 2.0;

  void _popToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
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
                    style: text.titleSuccess.copyWith(color: colors.textContent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content.subline,
                    textAlign: TextAlign.center,
                    style: text.body.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: 32),
                  if (content.amountText != null) ...[
                    Text(content.amountText!, style: text.amountInline.copyWith(color: colors.textContent)),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    '${l10n.sendTxSubmittedToLabel}:',
                    textAlign: TextAlign.center,
                    style: text.bodyEmphasis.copyWith(color: colors.textContent),
                  ),
                  const SizedBox(height: 16),
                  if (checksum != null && checksum.isNotEmpty) ...[
                    Text(
                      checksum,
                      textAlign: TextAlign.center,
                      style: text.body.copyWith(color: colors.semanticLilac),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    shortAddr,
                    textAlign: TextAlign.center,
                    style: text.dataAddressLarge.copyWith(color: colors.textContent),
                  ),
                  if (signaturesLabel != null) ...[
                    const SizedBox(height: 32),
                    _signaturesChip(context, colors, text, signaturesLabel),
                  ],
                ],
              ),
            ),
            if (content.explorerUrl != null) ...[
              const Spacer(),
              Center(child: ExplorerLink(url: content.explorerUrl)),
              const SizedBox(height: 20),
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

  Widget _signaturesChip(BuildContext context, AppColorsV3 colors, AppTextThemeV3 text, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fingerprint, size: 18, color: colors.textMuted),
          const SizedBox(width: 8),
          Text(label, style: text.body.copyWith(color: colors.textContent)),
        ],
      ),
    );
  }

  Widget _successMark(AppColorsV3 colors) {
    return Container(
      width: _successRingSize,
      height: _successRingSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.semanticSage, width: _borderWidth),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check_rounded, size: _checkIconSize, color: colors.semanticSage),
    );
  }
}
