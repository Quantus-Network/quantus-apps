import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Why a signing request was refused, with the one detail that identifies it
/// (the account, the key, the decoder's message) and a way back to home.
/// Shared by every signing screen so a refusal looks the same whatever the
/// chain.
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
    final text = context.themeTextV3;
    return ScaffoldBase(
      appBar: V2AppBar(title: appBarTitle),
      // The detail can be as long as a decoder's message, which no layout can
      // bound, so this column scrolls rather than overflowing on a small screen.
      mainContent: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: colors.semanticEmber.useOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(Icons.error_outline, size: 72, color: colors.semanticEmber),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: text.titleHero.copyWith(color: colors.semanticEmber),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: text.bodyLarge.copyWith(color: colors.textContent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.semanticEmber.useOpacity(0.08),
                  borderRadius: context.radiusV3.mdBorder,
                  border: Border.all(color: colors.semanticEmber),
                ),
                child: detail,
              ),
              const SizedBox(height: 20),
              Text(
                'Nothing was signed.',
                style: text.bodyEmphasis.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Back to home', onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ),
    );
  }
}
