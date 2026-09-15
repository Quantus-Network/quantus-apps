import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/import/import_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/onboarding_background.dart';

class WelcomeScreenV2 extends ConsumerStatefulWidget {
  const WelcomeScreenV2({super.key});

  @override
  ConsumerState<WelcomeScreenV2> createState() => _WelcomeScreenV2State();
}

class _WelcomeScreenV2State extends ConsumerState<WelcomeScreenV2> {
  bool _isCreating = false;

  Future<void> _createWallet() async {
    setState(() => _isCreating = true);
    await createSoftwareWalletFlow(context, ref);
    if (mounted) setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      key: const Key(E2EKeys.welcomeScreen),
      backgroundWidget: const OnboardingBackground(),
      mainContent: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Image.asset('assets/v2/quantus_orange_logo.png', height: 32),
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            child: Text(
              l10n.welcomeTagline,
              textAlign: TextAlign.center,
              style: text.titleHero.copyWith(color: colors.textWhite),
            ),
          ),
          const SizedBox(height: 56),
          QuantusButton.simple(
            key: const Key(E2EKeys.welcomeCreateWalletButton),
            label: l10n.welcomeCreateNewWallet,
            onTap: _createWallet,
            isLoading: _isCreating,
          ),
          const SizedBox(height: 24),
          QuantusButton.simple(
            key: const Key(E2EKeys.welcomeImportWalletButton),
            label: l10n.welcomeImportWallet,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'import_wallet'),
                builder: (_) => const ImportWalletScreenV2(),
              ),
            ),
            variant: ButtonVariant.staged,
            isDisabled: _isCreating,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
