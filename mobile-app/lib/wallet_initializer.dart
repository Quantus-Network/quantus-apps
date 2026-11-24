import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/mainnet_migration_provider.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/mainnet_migration_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/welcome_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/logout_flow.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';

class WalletInitializer extends ConsumerStatefulWidget {
  const WalletInitializer({super.key});

  @override
  ConsumerState<WalletInitializer> createState() => WalletInitializerState();
}

class WalletInitializerState extends ConsumerState<WalletInitializer> {
  bool _loading = true;
  bool _walletExists = false;
  bool _migrationPending = false;
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _checkWallet();
  }

  Future<void> _checkWallet() async {
    final hasWallet = await _settingsService.getHasWallet();

    if (hasWallet) {
      final mnemonic = await _settingsService.getMnemonic(0);
      if (mnemonic == null) {
        TelemetryService().sendEvent('user_lost_mnemonic');
        if (mounted) await _askAboutLostPhrase();
        return;
      }
    }
    _open(hasWallet: hasWallet);
  }

  /// Shows the wallet, or Welcome when there is none.
  void _open({required bool hasWallet}) {
    if (hasWallet) unawaited(_resumePendingAccountScans());
    setState(() {
      _walletExists = hasWallet;
      _migrationPending = hasWallet && ref.read(mainnetMigrationPendingProvider);
      _loading = false;
    });
  }

  Future<void> _resumePendingAccountScans() async {
    try {
      if (await WalletCreationService().resumePendingAccountScans() && mounted) invalidateAccountProviders(ref);
    } catch (e) {
      quantusPrint('Resuming pending account scans failed: $e');
      TelemetryService().sendError('Resuming pending account scans failed', error: e);
    }
  }

  /// Says the first wallet's recovery phrase cannot be read, and asks until
  /// the person chooses: Try Again reads it again, and the wallet is wiped
  /// only when its removal is confirmed. The phrase may still be on the
  /// device, hidden from the app for now. A sheet dismissed without a choice
  /// is shown again.
  Future<void> _askAboutLostPhrase() async {
    final l10n = ref.read(l10nProvider);

    while (true) {
      if (!mounted) return;
      final choice = await BottomSheetContainer.show<_LostPhraseChoice>(
        context,
        builder: (ctx) => BottomSheetContainer(
          title: l10n.walletInitErrorTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.walletInitErrorMessage, style: ctx.themeTextV3.body),
              const SizedBox(height: 32),
              QuantusButton.simple(
                label: l10n.commonTryAgain,
                onTap: () => Navigator.pop(ctx, _LostPhraseChoice.tryAgain),
              ),
              const SizedBox(height: 12),
              QuantusButton.simple(
                label: l10n.walletInitErrorRemoveWallet,
                variant: ButtonVariant.danger,
                onTap: () => Navigator.pop(ctx, _LostPhraseChoice.removeWallet),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      switch (choice) {
        case _LostPhraseChoice.tryAgain:
          if (await _settingsService.getMnemonic(0) != null) {
            if (mounted) _open(hasWallet: true);
            return;
          }
        case _LostPhraseChoice.removeWallet:
          final confirmed = await showQuantusDialog(
            context,
            title: l10n.walletInitErrorRemoveTitle,
            body: l10n.walletInitErrorRemoveBody,
            actionLabel: l10n.walletInitErrorRemoveConfirm,
            cancelLabel: l10n.commonCancel,
            isDestructive: true,
          );
          if (confirmed && mounted) {
            await logoutAndReturnToWelcome(context, ref);
            return;
          }
        case null:
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ScaffoldBase(mainContent: Center(child: Loader()));
    }

    if (!_walletExists) return const WelcomeScreenV2();
    if (_migrationPending) {
      return MainnetMigrationScreen(onFinished: () => setState(() => _migrationPending = false));
    }
    return const HomeScreen();
  }
}

/// What the person chose on the sheet saying the recovery phrase cannot be read.
enum _LostPhraseChoice { tryAgain, removeWallet }
