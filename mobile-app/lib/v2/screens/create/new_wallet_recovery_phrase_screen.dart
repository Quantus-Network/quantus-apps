import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/recovery_phrase_body.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_ready_screen.dart';

class NewWalletRecoveryPhraseScreen extends ConsumerStatefulWidget {
  const NewWalletRecoveryPhraseScreen({super.key});

  @override
  ConsumerState<NewWalletRecoveryPhraseScreen> createState() => _NewWalletRecoveryPhraseScreenState();
}

class _NewWalletRecoveryPhraseScreenState extends ConsumerState<NewWalletRecoveryPhraseScreen> {
  final WalletCreationService _walletCreationService = WalletCreationService();
  final HdWalletService _hdWalletService = HdWalletService();

  final String _accountName = 'Account 1';
  final int _walletIndex = 0;
  List<String> _words = [];
  String _mnemonic = '';
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _errorOccurred = false;

  late String _address;
  late String _checksum;

  Future<void> _generateMnemonic() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _mnemonic = await SubstrateService().generateMnemonic();
      if (_mnemonic.isEmpty) throw Exception('Mnemonic generation returned empty.');

      _words = _mnemonic.split(' ');
      _address = _hdWalletService.keyPairAtIndex(_mnemonic, 0).ss58Address;
      _checksum = await HumanReadableChecksumService().getHumanReadableName(_address);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorOccurred = true;
        });

        final l10n = ref.read(l10nProvider);
        context.showErrorToaster(message: l10n.createWalletRecoveryPhraseFailedGenerate(e.toString()));
      }
    }
  }

  Future<void> _continue() async {
    if (_words.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final accounts = ref.read(accountsProvider).value ?? <Account>[];
      await _walletCreationService.createNewWallet(
        name: _accountName,
        mnemonic: _mnemonic,
        walletIndex: _walletIndex,
        accountId: _address,
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
            accountId: _address,
            accountName: _accountName,
            checksumPhrase: _checksum,
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
  void initState() {
    super.initState();
    _generateMnemonic();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return RecoveryPhraseBody(
      appBarTitle: l10n.createWalletAppBarTitle,
      words: _words,
      primaryButtonLabel: l10n.createWalletRecoveryPhraseNext,
      onPrimary: _continue,
      isGridLoading: _isLoading,
      isPrimaryButtonDisabled: _errorOccurred,
      isPrimaryButtonLoading: _isLoading || _isSubmitting,
    );
  }
}
