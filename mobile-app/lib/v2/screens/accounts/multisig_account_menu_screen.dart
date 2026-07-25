import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/confirm_action_sheet.dart';
import 'package:resonance_network_wallet/v2/components/menu_divider.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_details_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/edit_account_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/multisig_details_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class MultisigAccountMenuScreen extends ConsumerWidget {
  final MultisigAccount initialAccount;

  const MultisigAccountMenuScreen({super.key, required this.initialAccount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    final accounts = ref.watch(multisigAccountsProvider);
    final account = accounts.value?.firstWhereOrNull((a) => a.accountId == initialAccount.accountId) ?? initialAccount;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.accountMenuTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _ProfileHeader(account: account, colors: colors, text: text),
          const SizedBox(height: 80),
          _MenuRow(
            label: l10n.accountMenuAccountName,
            value: account.name,
            onTap: () => _openNameEditor(context, ref, account),
          ),
          const MenuDivider(),
          _MenuRow(label: l10n.accountMenuAddressDetails, onTap: () => _openAddressDetails(context, account)),
          const MenuDivider(),
          _MenuRow(
            label: l10n.multisigAccountMenuDetails,
            value: l10n.multisigThresholdOf(account.threshold, account.signers.length),
            onTap: () => _openMultisigDetails(context, account),
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.accountMenuDisconnect,
          variant: ButtonVariant.danger,
          onTap: () => _onDisconnect(context, ref, account),
        ),
      ),
    );
  }

  Future<void> _onDisconnect(BuildContext context, WidgetRef ref, MultisigAccount account) async {
    final l10n = ref.read(l10nProvider);
    final confirmed = await showConfirmActionSheet(
      context,
      title: l10n.accountMenuDisconnectMultisigTitle,
      message: l10n.accountMenuDisconnectMultisigMessage(account.name),
      confirmLabel: l10n.accountMenuDisconnect,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(multisigAccountsProvider.notifier).remove(account.accountId);
      ref.invalidate(activeAccountProvider);
      if (context.mounted) returnToAccountsSheet(context, ref);
    } catch (e, st) {
      quantusDebugPrint('[MultisigAccountMenu] disconnect error: $e\n$st');
      if (context.mounted) context.showErrorToaster(message: l10n.accountMenuDisconnectError);
    }
  }

  Future<void> _openNameEditor(BuildContext context, WidgetRef ref, MultisigAccount current) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => EditAccountScreen.multisig(initialMultisig: current)));
    if (!context.mounted) return;
    ref.invalidate(multisigAccountsProvider);
  }

  void _openAddressDetails(BuildContext context, MultisigAccount account) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => AccountDetailsScreen(accountId: account.accountId)));
  }

  void _openMultisigDetails(BuildContext context, MultisigAccount account) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => MultisigDetailsScreen(account: account)));
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.account, required this.colors, required this.text});

  final MultisigAccount account;
  final AppColorsV2 colors;
  final AppTextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AccountBadge(
          name: account.name,
          isActive: true,
          size: 96,
          textStyle: text.largeTitle?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: -0.59,
            height: 1,
            fontFamily: AppTextTheme.fontFamilySecondary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          account.name,
          style: text.mediumTitle?.copyWith(fontWeight: FontWeight.w400, height: 1),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: text.paragraph?.copyWith(fontSize: 18))),
              Row(
                children: [
                  if (value != null) ...[
                    Text(value!, style: text.smallParagraph?.copyWith(color: colors.textMuted)),
                    const SizedBox(width: 4),
                  ],
                  Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
