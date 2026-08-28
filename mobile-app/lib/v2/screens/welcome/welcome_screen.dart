import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_ready_screen.dart';
import 'package:resonance_network_wallet/v2/screens/import/import_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/onboarding_background.dart';

class WelcomeScreenV2 extends ConsumerStatefulWidget {
  const WelcomeScreenV2({super.key});

  @override
  ConsumerState<WelcomeScreenV2> createState() => _WelcomeScreenV2State();
}

class _WelcomeScreenV2State extends ConsumerState<WelcomeScreenV2> {
  final WalletCreationService _walletCreationService = WalletCreationService();

  static const _accountName = 'Account 1';
  static const _walletIndex = 0;

  bool _isCreating = false;

  Future<void> _createWallet() async {
    setState(() => _isCreating = true);
    try {
      final mnemonic = await SubstrateService().generateMnemonic();
      if (mnemonic.isEmpty) throw Exception('Mnemonic generation returned empty.');

      final address = HdWalletService().keyPairAtIndex(mnemonic, 0).ss58Address;

      final accounts = ref.read(accountsProvider).value ?? <Account>[];
      await _walletCreationService.createNewWallet(
        name: _accountName,
        mnemonic: mnemonic,
        walletIndex: _walletIndex,
        accountId: address,
        existingAccounts: accounts,
      );

      // Software wallets always get a companion encrypted (wormhole) account.
      await ensureEncryptedAccounts(ref);

      invalidateAccountProviders(ref);
      ref.invalidate(walletOriginProvider(_walletIndex));
      ref.invalidate(recoveryPhraseViewedProvider(_walletIndex));

      unawaited(registerForRemoteNotificationsBestEffort(ref));

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => AccountReadyScreen(
            accountId: address,
            accountName: _accountName,
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
      if (mounted) setState(() => _isCreating = false);
    }
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
