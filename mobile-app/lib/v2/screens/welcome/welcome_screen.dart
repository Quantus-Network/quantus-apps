import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/create/wallet_ready_screen.dart';
import 'package:resonance_network_wallet/v2/screens/import/import_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/onboarding_background.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class WelcomeScreenV2 extends ConsumerWidget {
  const WelcomeScreenV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return ScaffoldBase(
      backgroundWidget: const OnboardingBackground(),
      mainContent: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Image.asset('assets/v2/quantus_orange_logo.png', height: 32),
          const SizedBox(height: 16),
          SizedBox(
            width: 210,
            child: Text(l10n.welcomeTagline, textAlign: TextAlign.center, style: context.themeText.mediumTitle),
          ),
          const SizedBox(height: 56),
          QuantusButton.simple(
            label: l10n.welcomeCreateNewWallet,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'create_wallet'),
                builder: (_) => const WalletReadyScreenV2(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          QuantusButton.simple(
            label: l10n.welcomeImportWallet,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'import_wallet'),
                builder: (_) => const ImportWalletScreenV2(),
              ),
            ),
            variant: ButtonVariant.secondary,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
