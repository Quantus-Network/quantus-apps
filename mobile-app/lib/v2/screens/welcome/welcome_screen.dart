import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_ready_screen.dart';
import 'package:resonance_network_wallet/v2/screens/import/import_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/onboarding_background.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class WelcomeScreenV2 extends ConsumerStatefulWidget {
  const WelcomeScreenV2({super.key});

  @override
  ConsumerState<WelcomeScreenV2> createState() => _WelcomeScreenV2State();
}

class _WelcomeScreenV2State extends ConsumerState<WelcomeScreenV2> {
  final WalletCreationService _walletCreationService = WalletCreationService();
  bool _isCreatingWallet = false;

  Future<void> _createWallet() async {
    setState(() => _isCreatingWallet = true);

    try {
      final accounts = ref.read(accountsProvider).value ?? <Account>[];
      final wallet = await _walletCreationService.createWalletWithGeneratedMnemonic(
        existingAccounts: accounts,
      );

      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);

      if (ref.read(remoteConfigProvider).enableRemoteNotifications) {
        ref.read(firebaseMessagingServiceProvider).registerDeviceIfPossible();
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => AccountReadyScreen(
            accountId: wallet.accountId,
            accountName: wallet.accountName,
            checksumPhrase: wallet.checksumPhrase,
            origin: AccountReadyOverviewOrigin.walletCreated,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        final l10n = ref.read(l10nProvider);
        context.showErrorToaster(message: l10n.createWalletRecoveryPhraseSaveError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isCreatingWallet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onTap: _createWallet,
            isLoading: _isCreatingWallet,
            isDisabled: _isCreatingWallet,
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
            isDisabled: _isCreatingWallet,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
