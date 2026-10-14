import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// Shown by the unlock-method step when the device has no lock, so the
/// signing key would be stored without user presence. Returns `true` if the
/// user chooses to proceed anyway.
class SecureElementWarningScreen extends StatelessWidget {
  const SecureElementWarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Security warning', showBackButton: false),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          Center(child: QuantusIcon(QuantusIcons.warning, size: 60, color: colors.semanticSand)),
          const SizedBox(height: 24),
          Text(
            'No device lock',
            style: text.titleHero.copyWith(color: colors.textContent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'This phone has no passcode or biometrics, so the signing key is stored without user presence. '
            'Anyone who picks up this phone can sign with it.\n\n'
            'Set a device lock first, or continue at your own risk.',
            style: text.bodyLarge.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(
              label: 'Go back',
              padding: coldButtonPadding,
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 12),
            QuantusButton.simple(
              label: 'Continue anyway',
              variant: ButtonVariant.secondary,
              padding: coldButtonPadding,
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
  }
}
