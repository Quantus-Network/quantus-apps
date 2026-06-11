import 'package:flutter/material.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// Shown during setup when the device reports no biometrics / device lock,
/// which we treat as a proxy for a missing hardware-backed secure element.
/// Returns `true` if the user chooses to proceed anyway.
class SecureElementWarningScreen extends StatelessWidget {
  const SecureElementWarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Security warning', leading: SizedBox(width: 24)),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.warning_amber_rounded, size: 64, color: colors.accentOrange),
          const SizedBox(height: 24),
          Text('No secure element detected', style: text.mediumTitle?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 16),
          Text(
            'This device has no biometrics or device lock configured, so your wallet key cannot be stored in a '
            'hardware-backed secure element. Your encrypted key will be protected only by your password.\n\n'
            'For a cold wallet we strongly recommend a device with a secure element and a device lock.',
            style: text.paragraph?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(label: 'Go back', onTap: () => Navigator.pop(context, false)),
            const SizedBox(height: 12),
            QuantusButton.simple(
              label: 'Continue anyway',
              variant: ButtonVariant.secondary,
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
  }
}
