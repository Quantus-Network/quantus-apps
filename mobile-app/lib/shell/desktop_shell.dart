import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shell/desktop_section.dart';
import 'package:resonance_network_wallet/shell/desktop_sidebar.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/activity/activity_screen.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/screens/receive/receive_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/encrypted_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/multisig_propose_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/select_recipient_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_screen.dart';

/// Provider for the currently active section in the desktop sidebar.
final desktopSelectedSectionProvider = StateProvider<DesktopSection>((ref) => DesktopSection.home);

/// Main two-panel shell for the desktop version of Quantus Wallet.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  final Map<DesktopSection, GlobalKey<NavigatorState>> _navigatorKeys = {
    for (final section in DesktopSection.values) section: GlobalKey<NavigatorState>(),
  };

  Widget _buildSectionPage(DesktopSection section) {
    switch (section) {
      case DesktopSection.home:
        return const HomeScreen();
      case DesktopSection.activity:
        return const ActivityScreen();
      case DesktopSection.receive:
        return const ReceiveScreen();
      case DesktopSection.send:
        return const _DesktopSendRoot();
      case DesktopSection.settings:
        return const SettingsScreenV2();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final selectedSection = ref.watch(desktopSelectedSectionProvider);

    return Scaffold(
      backgroundColor: colors.bgVoid,
      body: Row(
        children: [
          DesktopSidebar(
            selectedSection: selectedSection,
            onSectionSelected: (section) {
              if (selectedSection == section) {
                // If tapping the already selected section, pop to its root
                _navigatorKeys[section]?.currentState?.popUntil((route) => route.isFirst);
              } else {
                ref.read(desktopSelectedSectionProvider.notifier).state = section;
              }
            },
          ),
          Expanded(
            child: ColoredBox(
              color: colors.bgVoid,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: IndexedStack(
                    index: selectedSection.index,
                    children: [
                      for (final section in DesktopSection.values)
                        Navigator(
                          key: _navigatorKeys[section],
                          onGenerateRoute: (settings) =>
                              MaterialPageRoute<void>(settings: settings, builder: (_) => _buildSectionPage(section)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Root widget for the Desktop "Send" tab, resolving the active account strategy.
class _DesktopSendRoot extends ConsumerWidget {
  const _DesktopSendRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final accountAsync = ref.watch(activeAccountProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return accountAsync.when(
      loading: () => const ScaffoldBase(mainContent: Center(child: Loader())),
      error: (e, _) => ScaffoldBase(
        mainContent: Center(
          child: Text(l10n.homeError(e.toString()), style: text.caption.copyWith(color: colors.semanticEmber)),
        ),
      ),
      data: (active) {
        if (active == null) {
          return ScaffoldBase(
            mainContent: Center(
              child: Text(l10n.homeNoActiveAccount, style: text.body.copyWith(color: colors.textMuted)),
            ),
          );
        }

        final SendStrategy sendStrategy;
        if (active is MultisigDisplayAccount) {
          sendStrategy = MultisigProposeStrategy(msig: active.account);
        } else if (active is RegularAccount) {
          final isEncrypted = isEncryptedAccount(active.account);
          sendStrategy = isEncrypted
              ? EncryptedSendStrategy(account: active.account)
              : RegularSendStrategy(account: active.account);
        } else {
          return ScaffoldBase(
            mainContent: Center(
              child: Text(l10n.homeNoActiveAccount, style: text.body.copyWith(color: colors.textMuted)),
            ),
          );
        }

        return SelectRecipientScreen(strategy: sendStrategy);
      },
    );
  }
}
