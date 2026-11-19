import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/models/wallet_presence.dart';
import 'package:quantus_desktop_wallet/providers/boot_intro_provider.dart';
import 'package:quantus_desktop_wallet/providers/password_prompt_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/shortcut_bindings_provider.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/app_exit.dart';
import 'package:quantus_desktop_wallet/ui/approval/login_password_dialog.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/panel_resize_handle.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/boot_intro.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/onboarding_flow.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/app_menu.dart';
import 'package:quantus_desktop_wallet/ui/shell/app_menu_bar.dart';
import 'package:quantus_desktop_wallet/ui/shell/live_data_scope.dart';
import 'package:quantus_desktop_wallet/ui/shell/mining_rewards_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_footer.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_header.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/wallet_creation_service.dart';
import 'package:wallet_core/utils/provider_reader.dart';

/// The window's frame: the menus, and under them onboarding until the device
/// has a wallet, then the top bar over the panels (the sidebar, and beside it
/// the panes for what the sidebar has selected) over the footer, and the sheet
/// over them when one is open.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  /// The bar across the top of the window, which sheets hang from.
  static const topBarKey = Key('shell-top-bar');

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  static const _introFade = Duration(milliseconds: 500);
  static const _sheetSlide = Duration(milliseconds: 220);

  /// Whether the boot intro is covering Welcome.
  bool _isIntroPlaying = false;

  /// The top bar, which sheets hang from.
  final _topBar = GlobalKey();

  /// Where the top bar ends, in the coordinates sheets are drawn in.
  /// Measured rather than assumed: on Windows and Linux the menu bar sits in
  /// the window above it.
  double _sheetTop() {
    final bar = _topBar.currentContext?.findRenderObject() as RenderBox?;
    if (bar == null) throw StateError('A sheet was opened with no top bar to hang from.');
    final overlay = Navigator.of(context, rootNavigator: true).overlay!.context.findRenderObject()! as RenderBox;
    return bar.localToGlobal(Offset(0, bar.size.height), ancestor: overlay).dy;
  }

  void _present(ShellSheet? sheet) {
    if (sheet == null) return;
    final top = _sheetTop();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: context.colorsV3.bgVoid.useOpacity(0.6),
      transitionDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : _sheetSlide,
      pageBuilder: (_, animation, _) => _SheetPlacement(
        animation: animation,
        top: top,
        child: ShellSheetView(sheet: sheet),
      ),
      // The sheet slides itself; the barrier fades on its own.
      transitionBuilder: (_, _, _, child) => child,
    ).whenComplete(() {
      if (mounted) ref.read(shellSheetProvider.notifier).closed();
    });
  }

  /// Asks for the login password in a dialog over the window, and over the
  /// sheet that asked.
  Future<void> _askForPassword(PasswordPromptRequest request) async {
    final prompt = ref.read(passwordPromptProvider.notifier);
    final bool approved;
    try {
      approved = await showLoginPasswordDialog(context, request);
    } catch (error, stackTrace) {
      prompt.fail(error, stackTrace);
      return;
    }
    prompt.finish(approved: approved);
  }

  void _onWalletPresence(AsyncValue<WalletPresence>? previous, AsyncValue<WalletPresence> next) {
    switch (next.value) {
      case WalletPresence.phraseMissing:
        unawaited(_reportMissingPhrase());
      // Found by the check at start. A wallet that onboarding just added is
      // complete already.
      case WalletPresence.present when previous?.value == null:
        unawaited(_finishWalletSetup());
      // Likewise found at start: the intro comes before the first Welcome
      // only, not before one reached by wiping a wallet.
      case WalletPresence.none when previous?.value == null:
        _playIntroOnce();
      default:
    }
  }

  /// Plays the boot intro if this device has never shown it. With the
  /// system's reduced motion on it is left for a later start.
  void _playIntroOnce() {
    if (ref.read(bootIntroSeenProvider) || MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _isIntroPlaying = true);
    // Recorded as it starts, so quitting half way does not bring it back.
    unawaited(ref.read(bootIntroSeenProvider.notifier).markSeen());
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
    if (mounted) await ref.read(walletPresenceProvider.notifier).wipeWallet();
  }

  /// Says an account could not be made the active account, and why.
  Future<void> _reportSwitchFailure(AccountSwitchFailure failure) async {
    final l10n = ref.read(l10nProvider);
    await showQuantusDialog(
      context,
      title: l10n.desktopAccountSwitchFailedTitle,
      body: l10n.desktopAccountSwitchFailedMessage(failure.account.account.name, '${failure.error}'),
      actionLabel: l10n.commonClose,
      showCancel: false,
    );
    if (mounted) ref.read(accountSwitchFailureProvider.notifier).clear();
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
    ref.listen<PasswordPromptRequest?>(passwordPromptProvider, (_, request) {
      if (request != null) unawaited(_askForPassword(request));
    });
    ref.listen<AsyncValue<WalletPresence>>(walletPresenceProvider, _onWalletPresence);
    ref.listen<AccountSwitchFailure?>(accountSwitchFailureProvider, (_, failure) {
      if (failure != null) unawaited(_reportSwitchFailure(failure));
    });

    final useNativeMenuBar = defaultTargetPlatform == TargetPlatform.macOS;
    final isSidebarVisible = ref.watch(sidebarVisibleProvider);
    final presence = ref.watch(walletPresenceProvider);

    return Scaffold(
      body: AppMenuBar(
        useNativeMenuBar: useNativeMenuBar,
        menus: _menus(ref.watch, useNativeMenuBar: useNativeMenuBar),
        resolveMenus: () => _menus(ref.read, useNativeMenuBar: useNativeMenuBar),
        child: switch (presence) {
          AsyncError(:final error) => _StartFailure(error: error),
          AsyncValue(value: WalletPresence.present) => LiveDataScope(child: _wallet(isSidebarVisible)),
          AsyncValue(value: WalletPresence.none) => AnimatedSwitcher(
            duration: _introFade,
            child: _isIntroPlaying
                ? BootIntro(onFinished: () => setState(() => _isIntroPlaying = false))
                : OnboardingFlow(
                    // Both run on the shell's ref, not the flow's: an import
                    // restores the wallet's encrypted account after the flow
                    // has left the window.
                    createWallet: () => createSoftwareWallet(ref),
                    // Onboarding runs only on a device with no wallet, so the
                    // wallet it imports is the first.
                    importWallet: (mnemonic, {required onScanFailed}) =>
                        importSoftwareWallet(ref, mnemonic: mnemonic, walletIndex: 0, onScanFailed: onScanFailed),
                    onFinished: () => ref.read(walletPresenceProvider.notifier).walletAdded(),
                  ),
          ),
          // Still checking, or about to wipe a wallet whose phrase is gone.
          _ => const Center(child: Loader()),
        },
      ),
    );
  }

  /// The app's menus for what [read] finds: watched, as they are drawn; read
  /// at a key press, as they are at that moment.
  List<PlatformMenu> _menus(ProviderReader read, {required bool useNativeMenuBar}) {
    // The Account and View menus act on the wallet, so they wait for one.
    final hasWallet = read(walletPresenceProvider).value == WalletPresence.present;
    final hasSheet = read(shellSheetProvider) != null;
    // A sheet is for the account it opened on, so nothing moves under it.
    final canNavigate = hasWallet && !hasSheet;
    final sidebar = ref.read(sidebarSelectionProvider.notifier);

    return buildAppMenus(
      l10n: read(l10nProvider),
      useNativeMenuBar: useNativeMenuBar,
      accountActions: read(menuAccountActionsProvider),
      accounts: hasWallet ? read(sidebarAccountsProvider) : const [],
      shortcuts: read(isRecordingShortcutProvider) ? null : read(shortcutBindingsProvider).bindings,
      isSidebarVisible: read(sidebarVisibleProvider),
      canOpenSheet: canNavigate,
      onOpenSheet: (sheet) => ref.read(shellSheetProvider.notifier).open(sheet),
      onShowAccount: canNavigate ? (account) => unawaited(sidebar.showAccount(account)) : null,
      onMoveInSidebar: canNavigate ? (rows) => unawaited(sidebar.move(rows)) : null,
      onToggleSidebar: hasWallet ? () => ref.read(sidebarVisibleProvider.notifier).toggle() : null,
      onRefresh: hasWallet ? () => unawaited(refreshWallet(ref)) : null,
      onCloseWindow: () => ref.read(requestAppExitProvider)(),
    );
  }

  Widget _wallet(bool isSidebarVisible) {
    final sidebarWidth = ref.watch(sidebarWidthProvider);
    final sidebar = ref.read(sidebarWidthProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: _topBar,
          child: const ShellTopBar(key: DesktopShell.topBarKey),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Panel.gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isSidebarVisible) ...[
                  SizedBox(width: sidebarWidth, child: const Sidebar()),
                  PanelResizeHandle(
                    width: sidebarWidth,
                    onResize: sidebar.resizeTo,
                    onResizeEnd: () => unawaited(sidebar.save()),
                  ),
                ],
                Expanded(
                  child: switch (ref.watch(sidebarSelectionProvider)) {
                    SidebarSelection.account => const AccountPane(),
                    SidebarSelection.miningRewards => const MiningRewardsPane(),
                  },
                ),
              ],
            ),
          ),
        ),
        const ShellFooter(),
      ],
    );
  }
}

/// Where a sheet goes: hanging from the bottom of the top bar, [top] down
/// the window, centred on the panels beside the sidebar, sliding down from
/// under the bar as [animation] runs.
class _SheetPlacement extends ConsumerWidget {
  const _SheetPlacement({required this.animation, required this.top, required this.child});

  final Animation<double> animation;
  final double top;
  final Widget child;

  /// Space kept between a sheet and the panels' sides.
  static const double _sideMargin = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panelsLeft = ref.watch(sidebarVisibleProvider)
        ? Panel.gap + ref.watch(sidebarWidthProvider) + Panel.gap
        : Panel.gap;

    return Padding(
      padding: EdgeInsets.only(left: panelsLeft, right: Panel.gap, top: top),
      // Clipped at the bar, so the sheet comes out from under it.
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
            child: ConstrainedBox(
              // As wide as a sheet grows, or as the pane allows.
              constraints: const BoxConstraints.tightFor(width: ShellSheetView.maxWidth),
              child: SlideTransition(
                position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
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
