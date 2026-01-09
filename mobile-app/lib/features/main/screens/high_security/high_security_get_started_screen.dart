import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/high_security_guardian_wizard.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/high_security_form_provider.dart';

class HighSecurityGetStartedScreen extends ConsumerWidget {
  const HighSecurityGetStartedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formNotifier = ref.read(highSecurityFormProvider.notifier);

    return ScaffoldBase(
      appBar: WalletAppBar.simpleWithBackButton(title: 'Security Settings'),
      child: Column(
        children: [
          const SizedBox(height: 73),
          SvgPicture.asset('assets/high_security/security_icon_big.svg', width: 140, height: 175),
          const SizedBox(height: 26),
          Text('HIGH SECURITY', style: context.themeText.largeTitle),
          const SizedBox(height: 25),
          Text(
            "Don't risk your funds!\nEnabling High Security is a great way to keep your money safe. But safety comes at the cost of convenience.",
            textAlign: TextAlign.center,
            style: context.themeText.paragraph,
          ),
          const SizedBox(height: 13),
          Text(
            'Once you enable this feature it cannot be disabled',
            textAlign: TextAlign.center,
            style: context.themeText.paragraph?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Expanded(child: SizedBox()),
          Button(
            variant: ButtonVariant.neutral,
            label: 'Start',
            onPressed: () {
              formNotifier.resetState();
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HighSecurityGuardianWizard()));
            },
          ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }
}
