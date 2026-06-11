import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_ready_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_caution_scaffold.dart';

class WalletReadyScreenV2 extends ConsumerStatefulWidget {
  const WalletReadyScreenV2({super.key});

  @override
  ConsumerState<WalletReadyScreenV2> createState() => _WalletReadyScreenV2State();
}

class _WalletReadyScreenV2State extends ConsumerState<WalletReadyScreenV2> {
  final WalletCreationService _walletCreationService = WalletCreationService();

  static const _accountName = 'Account 1';
  static const _walletIndex = 0;

  bool _isSubmitting = false;

  Future<void> _continue() async {
    setState(() => _isSubmitting = true);
    try {
      final mnemonic = await SubstrateService().generateMnemonic();
      if (mnemonic.isEmpty) throw Exception('Mnemonic generation returned empty.');

      final address = HdWalletService().keyPairAtIndex(mnemonic, 0).ss58Address;
      final checksum = await HumanReadableChecksumService().getHumanReadableName(address);

      final accounts = ref.read(accountsProvider).value ?? <Account>[];
      await _walletCreationService.createNewWallet(
        name: _accountName,
        mnemonic: mnemonic,
        walletIndex: _walletIndex,
        accountId: address,
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
            accountId: address,
            accountName: _accountName,
            checksumPhrase: checksum,
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return SettingsCautionScaffold(
      appBarTitle: l10n.createWalletAppBarTitle,
      data: SettingsCautionScaffoldData.recoveryPhrase(l10n),
      continueLabel: l10n.commonContinue,
      onContinue: _continue,
      continueButtonLoading: _isSubmitting,
    );
  }
}
