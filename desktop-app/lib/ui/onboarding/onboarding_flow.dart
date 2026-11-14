import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/import_wallet_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/wallet_created_page.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

enum _Step { welcome, importWallet, walletCreated }

/// What fills the window while the device has no wallet: Welcome, then either
/// a new wallet and the page that announces it, or the import page.
///
/// [createWallet] and [importWallet] do the work; [onFinished] is called once
/// the wallet is there and the user is done here.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, required this.createWallet, required this.importWallet, required this.onFinished});

  final Future<Account> Function() createWallet;
  final ImportWallet importWallet;
  final VoidCallback onFinished;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  _Step _step = _Step.welcome;
  bool _isCreating = false;
  String? _createError;
  Account? _created;

  Future<void> _createWallet() async {
    setState(() {
      _isCreating = true;
      _createError = null;
    });

    try {
      final account = await widget.createWallet();
      if (!mounted) return;
      setState(() {
        _created = account;
        _step = _Step.walletCreated;
      });
    } catch (e) {
      quantusPrint('Wallet creation failed: $e');
      if (mounted) setState(() => _createError = ref.read(l10nProvider).createWalletRecoveryPhraseSaveError('$e'));
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.welcome => WelcomePage(
        isCreating: _isCreating,
        error: _createError,
        onCreateWallet: _createWallet,
        onImportWallet: () => setState(() => _step = _Step.importWallet),
      ),
      _Step.importWallet => ImportWalletPage(
        importWallet: widget.importWallet,
        onImported: widget.onFinished,
        onBack: () => setState(() => _step = _Step.welcome),
      ),
      _Step.walletCreated => WalletCreatedPage(account: _created!, onGoToWallet: widget.onFinished),
    };
  }
}
