import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/models/wallet_presence.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_flow.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/app_menu.dart';
import 'package:quantus_desktop_wallet/ui/shell/app_menu_bar.dart';
import 'package:quantus_desktop_wallet/ui/shell/mining_rewards_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';

/// The window's frame: the menus, and under them onboarding until the device
/// has a wallet, then the sidebar, the pane for what the sidebar has selected
/// under its header, and the sheet over them when one is open.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  void _present(ShellSheet? sheet) {
    if (sheet == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => ShellSheetView(sheet: sheet),
    ).whenComplete(() {
      if (mounted) ref.read(shellSheetProvider.notifier).closed();
    });
  }

  void _onWalletPresence(AsyncValue<WalletPresence>? previous, AsyncValue<WalletPresence> next) {
    switch (next.value) {
      case WalletPresence.phraseMissing:
        unawaited(_reportMissingPhrase());
      // Found by the check at start. A wallet that onboarding just added is
      // complete already.
      case WalletPresence.present when previous?.value == null:
        unawaited(_finishWalletSetup());
      default:
    }
  }

  /// Says the wallet cannot be used, then wipes it so it can be set up again.
  Future<void> _reportMissingPhrase() async {
    final l10n = ref.read(l10nProvider);
    await showQuantusDialog(
      context,
      title: l10n.walletInitErrorTitle,
      body: l10n.walletInitErrorMessage,
      actionLabel: l10n.walletInitErrorButtonLabel,
      showCancel: false,
      barrierDismissible: false,
    );
    if (!mounted) return;
    await ref.read(logoutServiceProvider).logout();
    if (mounted) ref.read(walletPresenceProvider.notifier).walletRemoved();
  }

  /// Finishes what an earlier run left undone: an import's account scan that
  /// was skipped or interrupted, and a software wallet's encrypted account.
  Future<void> _finishWalletSetup() async {
    try {
      final scanned = await ref.read(walletCreationServiceProvider).resumePendingAccountScans();
      if (!mounted) return;
      final encryptedAdded = await ensureEncryptedAccounts(ref);
      if (mounted && (scanned || encryptedAdded)) invalidateAccountProviders(ref);
    } catch (e) {
      quantusPrint('Finishing the wallet setup at start failed: $e');
      if (mounted) ref.read(telemetryProvider).sendError('Finishing the wallet setup at start failed', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ShellSheet?>(shellSheetProvider, (_, sheet) => _present(sheet));
    ref.listen<AsyncValue<WalletPresence>>(walletPresenceProvider, _onWalletPresence);

    final useNativeMenuBar = defaultTargetPlatform == TargetPlatform.macOS;
    final isSidebarVisible = ref.watch(sidebarVisibleProvider);
    final presence = ref.watch(walletPresenceProvider);
    // The Account and View menus act on the wallet, so they wait for one.
    final hasWallet = presence.value == WalletPresence.present;

    return Scaffold(
      body: AppMenuBar(
        useNativeMenuBar: useNativeMenuBar,
        menus: buildAppMenus(
          l10n: ref.watch(l10nProvider),
          useNativeMenuBar: useNativeMenuBar,
          accountActions: ref.watch(activeAccountActionsProvider),
          isSidebarVisible: isSidebarVisible,
          canOpenSheet: hasWallet && ref.watch(shellSheetProvider) == null,
          onOpenSheet: (sheet) => ref.read(shellSheetProvider.notifier).open(sheet),
          onToggleSidebar: hasWallet ? () => ref.read(sidebarVisibleProvider.notifier).toggle() : null,
          onCloseWindow: () => ref.read(requestAppExitProvider)(),
        ),
        child: switch (presence) {
          AsyncError(:final error) => _StartFailure(error: error),
          AsyncValue(value: WalletPresence.present) => _wallet(isSidebarVisible),
          AsyncValue(value: WalletPresence.none) => OnboardingFlow(
            // Both run on the shell's ref, not the flow's: an import restores
            // the wallet's encrypted account after the flow has left the window.
            createWallet: () => createSoftwareWallet(ref),
            // Onboarding runs only on a device with no wallet, so the wallet
            // it imports is the first.
            importWallet: (mnemonic, {required onScanFailed}) =>
                importSoftwareWallet(ref, mnemonic: mnemonic, walletIndex: 0, onScanFailed: onScanFailed),
            onFinished: () => ref.read(walletPresenceProvider.notifier).walletAdded(),
          ),
          // Still checking, or about to wipe a wallet whose phrase is gone.
          _ => const Center(child: Loader()),
        },
      ),
    );
  }

  Widget _wallet(bool isSidebarVisible) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isSidebarVisible) const Sidebar(),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PaneHeader(),
              Expanded(
                child: switch (ref.watch(sidebarSelectionProvider)) {
                  SidebarSelection.account => const AccountPane(),
                  SidebarSelection.miningRewards => const MiningRewardsPane(),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown when the check for a wallet itself failed: the app cannot tell what
/// is on the device, so it says why and offers nothing else.
class _StartFailure extends StatelessWidget {
  const _StartFailure({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$error',
          textAlign: TextAlign.center,
          style: context.themeTextV3.body.copyWith(color: context.colorsV3.semanticEmber),
        ),
      ),
    );
  }
}
