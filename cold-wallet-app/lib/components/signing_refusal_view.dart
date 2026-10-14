import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/outcome_view.dart';
import 'package:quantus_cold_wallet/screens/rejected_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// Why a signing request was refused (Figma Cold Wallet / Unreadable), with
/// the one detail that identifies it (the account, the key, the decoder's
/// message). Shared by every signing screen so a refusal looks the same
/// whatever the chain; Reject leads to the Rejected screen.
class SigningRefusalView extends StatelessWidget {
  final String appBarTitle;
  final String title;
  final String message;
  final Widget detail;

  const SigningRefusalView({
    super.key,
    required this.appBarTitle,
    required this.title,
    required this.message,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return OutcomeView(
      appBarTitle: appBarTitle,
      glyph: QuantusIcons.warningCircle,
      glyphColor: colors.semanticEmber,
      title: title,
      body: message,
      bottom: QuantusButton.simple(
        label: 'Reject',
        padding: coldButtonPadding,
        onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RejectedScreen())),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: context.radiusV3.mdBorder,
            border: Border.all(color: colors.borderHairline),
          ),
          child: detail,
        ),
        const SizedBox(height: 20),
        Text(
          'Nothing was signed.',
          style: context.themeTextV3.bodyEmphasis.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
