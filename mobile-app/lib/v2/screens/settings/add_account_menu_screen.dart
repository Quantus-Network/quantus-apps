import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/add_hardware_account_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/create_account_screen.dart';
import 'package:resonance_network_wallet/v2/screens/import/import_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/add_multisig_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/discover_multisig_screen.dart';

class AddAccountMenuScreen extends ConsumerStatefulWidget {
  const AddAccountMenuScreen({super.key});

  @override
  ConsumerState<AddAccountMenuScreen> createState() => _AddAccountMenuScreenState();
}

class _AddAccountMenuScreenState extends ConsumerState<AddAccountMenuScreen> {
  bool _advancedExpanded = false;

  void _onCreateNewAccount() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateAccountScreen()));
  }

  void _onImportWallet() {
    final accounts = ref.read(accountsProvider).value ?? <Account>[];
    final walletIndex = nextWalletIndex(accounts);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImportWalletScreenV2(walletIndex: walletIndex, openAccountsOnComplete: true)),
    );
  }

  void _onImportKeystone() {
    final accounts = ref.read(accountsProvider).value ?? <Account>[];
    final walletIndex = nextWalletIndex(accounts);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddHardwareAccountScreen(walletIndex: walletIndex, isNewWallet: true)));
  }

  void _onDiscoverMultisig() {
    ref.invalidate(discoveredMultisigsProvider);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverMultisigScreen()));
  }

  void _onCreateMultisig() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMultisigScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final enableKeystone = ref.watch(remoteConfigProvider).enableKeystoneHardwareWallet;
    final enableMultisig = ref.watch(remoteConfigProvider).enableMultisig;
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.addAccountMenuTitle),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: l10n.commonDone, onTap: () => Navigator.pop(context)),
      ),
      mainContent: ListView(
        children: [
          const SizedBox(height: 16),
          _AccountOptionCard(
            icon: Icons.add,
            title: l10n.addAccountMenuCreateTitle,
            subtitle: l10n.addAccountMenuCreateSubtitle,
            onTap: _onCreateNewAccount,
            colors: colors,
            text: text,
          ),
          const SizedBox(height: 14),
          if (enableKeystone) ...[
            _AccountOptionCard(
              icon: Icons.qr_code_scanner,
              title: l10n.addAccountMenuImportKeystoneTitle,
              subtitle: l10n.addAccountMenuImportKeystoneSubtitle,
              onTap: _onImportKeystone,
              colors: colors,
              text: text,
            ),
            const SizedBox(height: 14),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: colors.separator, height: 1),
          ),
          _AdvancedSection(
            title: l10n.addAccountMenuMoreTitle,
            expanded: _advancedExpanded,
            onToggle: () => setState(() => _advancedExpanded = !_advancedExpanded),
            colors: colors,
            text: text,
            children: [
              if (enableMultisig) ...[
                GestureDetector(
                  onTap: _onDiscoverMultisig,
                  behavior: HitTestBehavior.opaque,
                  child: _AccountOptionRowContent(
                    icon: Icons.radar_outlined,
                    title: l10n.addAccountMenuDiscoverMultisigTitle,
                    subtitle: l10n.addAccountMenuDiscoverMultisigSubtitle,
                    colors: colors,
                    text: text,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: colors.separator, height: 1),
                ),
                GestureDetector(
                  onTap: _onCreateMultisig,
                  behavior: HitTestBehavior.opaque,
                  child: _AccountOptionRowContent(
                    icon: Icons.group_outlined,
                    title: l10n.addAccountMenuMultisigTitle,
                    subtitle: l10n.addAccountMenuMultisigSubtitle,
                    colors: colors,
                    text: text,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: colors.separator, height: 1),
                ),
              ],
              GestureDetector(
                onTap: _onImportWallet,
                behavior: HitTestBehavior.opaque,
                child: _AccountOptionRowContent(
                  icon: Icons.save_alt,
                  title: l10n.addAccountMenuImportTitle,
                  subtitle: l10n.addAccountMenuImportSubtitle,
                  colors: colors,
                  text: text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountOptionCard extends StatelessWidget {
  const _AccountOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.colors,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final AppColorsV2 colors;
  final AppTextTheme text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceDeep,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _AccountOptionRowContent(icon: icon, title: title, subtitle: subtitle, colors: colors, text: text),
        ),
      ),
    );
  }
}

class _AccountOptionRowContent extends StatelessWidget {
  const _AccountOptionRowContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppColorsV2 colors;
  final AppTextTheme text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: colors.sheetBackground, shape: BoxShape.circle),
          child: Center(child: Icon(icon, size: 16, color: colors.accentOrange)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.paragraph?.copyWith(fontSize: 18, color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: text.detail?.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
        Icon(Icons.chevron_right, size: 20, color: colors.textMuted),
      ],
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.colors,
    required this.text,
    required this.children,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: text.paragraph?.copyWith(fontSize: 18, color: colors.textPrimary)),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down, size: 20, color: colors.textMuted),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Divider(color: colors.separator, height: 1),
                      ),
                      const SizedBox(height: 16),
                      ...children,
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
