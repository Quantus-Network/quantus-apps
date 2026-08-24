import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown when the Keystone screen does not match what the app asked it to
/// sign: tells the user to reject on the device and not retry from this phone.
/// Pops with `true` once the user confirms the rejection.
class KeystoneRejectScreen extends ConsumerWidget {
  const KeystoneRejectScreen({super.key});

  static final Uri _supportUrl = Uri.parse('mailto:${AppConstants.emailSupport}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    final steps = [
      (l10n.keystoneRejectStep1Title, l10n.keystoneRejectStep1Body),
      (l10n.keystoneRejectStep2Title, l10n.keystoneRejectStep2Body),
      (l10n.keystoneRejectStep3Title, l10n.keystoneRejectStep3Body),
    ];

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.keystoneSignScreenTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KeystoneWarningCard(title: l10n.keystoneRejectTitle, text: l10n.keystoneVerifyWarning),
            const SizedBox(height: 40),
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: MenuDivider()),
              _RejectStep(number: '0${i + 1}', title: steps[i].$1, body: steps[i].$2),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(label: l10n.keystoneRejectConfirm, onTap: () => Navigator.pop(context, true)),
            const SizedBox(height: 4),
            QuantusButton.simple(
              label: l10n.keystoneRejectContactSupport,
              variant: ButtonVariant.underline,
              onTap: () => launchUrl(_supportUrl),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectStep extends StatelessWidget {
  final String number;
  final String title;
  final String body;

  const _RejectStep({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number, style: text.bodyLarge.copyWith(color: colors.accentFlare)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.body.copyWith(color: colors.textContent)),
              const SizedBox(height: 4),
              Text(body, style: text.caption.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
