import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/create_account_screen.dart';
import 'package:resonance_network_wallet/v2/screens/import/import_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/add_multisig_screen.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/discover_multisig_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AddAccountMenuScreen extends ConsumerStatefulWidget {
  const AddAccountMenuScreen({super.key});

  @override
  ConsumerState<AddAccountMenuScreen> createState() => _AddAccountMenuScreenState();
}

class _AddAccountMenuScreenState extends ConsumerState<AddAccountMenuScreen> {
  void _onCreateNewAccount() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateAccountScreen()));
  }

  void _onImportWallet() {
    final accounts = ref.read(accountsProvider).value ?? <Account>[];
    final walletIndex = nextNonHardwareWalletIndex(accounts);

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImportWalletScreenV2(walletIndex: walletIndex)));
  }

  void _onAddMultisig() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMultisigScreen()));
  }

  void _onDiscoverMultisig() {
    ref.invalidate(discoveredMultisigsProvider);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiscoverMultisigScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.addAccountMenuTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AddMenuRow(
            icon: Icons.add,
            title: l10n.addAccountMenuCreateTitle,
            subtitle: l10n.addAccountMenuCreateSubtitle,
            onTap: _onCreateNewAccount,
            colors: colors,
            text: context.themeText,
          ),
          const SizedBox(height: 16),
          Divider(color: colors.toasterBackground, height: 1),
          const SizedBox(height: 24),
          _AddMenuRow(
            icon: Icons.group_outlined,
            title: l10n.addAccountMenuMultisigTitle,
            subtitle: l10n.addAccountMenuMultisigSubtitle,
            onTap: _onAddMultisig,
            colors: colors,
            text: context.themeText,
          ),
          const SizedBox(height: 16),
          Divider(color: colors.toasterBackground, height: 1),
          const SizedBox(height: 24),
          _AddMenuRow(
            icon: Icons.radar_outlined,
            title: l10n.addAccountMenuDiscoverMultisigTitle,
            subtitle: l10n.addAccountMenuDiscoverMultisigSubtitle,
            onTap: _onDiscoverMultisig,
            colors: colors,
            text: context.themeText,
          ),
          const SizedBox(height: 16),
          Divider(color: colors.toasterBackground, height: 1),
          const SizedBox(height: 24),
          _AddMenuRow(
            icon: Icons.save_alt,
            title: l10n.addAccountMenuImportTitle,
            subtitle: l10n.addAccountMenuImportSubtitle,
            onTap: _onImportWallet,
            colors: colors,
            text: context.themeText,
          ),
        ],
      ),
    );
  }
}

class _AddMenuRow extends StatelessWidget {
  const _AddMenuRow({
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
    final containerSize = 40.0;
    final iconSize = 20.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: containerSize,
              height: containerSize,
              child: Center(
                child: Icon(icon, size: iconSize, color: colors.accentOrange),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.paragraph?.copyWith(fontSize: 18)),
                  Text(subtitle, style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
