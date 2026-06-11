import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/wallet_creation_service.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/recovery_phrase_body.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/wallet_onboarding_flow.dart';

class NewWalletRecoveryPhraseScreen extends ConsumerStatefulWidget {
  const NewWalletRecoveryPhraseScreen({super.key});

  @override
  ConsumerState<NewWalletRecoveryPhraseScreen> createState() => _NewWalletRecoveryPhraseScreenState();
}

class _NewWalletRecoveryPhraseScreenState extends ConsumerState<NewWalletRecoveryPhraseScreen> {
  final WalletCreationService _walletCreationService = WalletCreationService();

  GeneratedWalletPreview? _preview;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _errorOccurred = false;

  List<String> get _words => _preview?.mnemonic.split(' ') ?? const [];

  Future<void> _generateMnemonic() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final preview = await _walletCreationService.generateWalletPreview();
      if (mounted) {
        setState(() {
          _preview = preview;
          _isLoading = false;
        });
      }
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
    final preview = _preview;
    if (preview == null) return;

    setState(() => _isSubmitting = true);
    try {
      final accounts = ref.read(accountsProvider).value ?? <Account>[];
      final wallet = await _walletCreationService.persistWalletPreview(
        preview: preview,
        existingAccounts: accounts,
      );

      if (!mounted) return;
      await completeWalletOnboarding(ref: ref, context: context, wallet: wallet);
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
