import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_details_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/edit_account_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_confirmation_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AccountMenuScreen extends ConsumerWidget {
  final Account initialAccount;

  const AccountMenuScreen({super.key, required this.initialAccount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = context.themeText;

    final accounts = ref.watch(accountsProvider);
    final account = accounts.value?.firstWhere((a) => a.accountId == initialAccount.accountId);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Accounts'),
      mainContent: account != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _ProfileHeader(account: account, colors: colors, text: text),
                const SizedBox(height: 80),
                _MenuRow(
                  label: 'Account Name',
                  value: account.name,
                  onTap: () => _openNameEditor(context, ref, account),
                ),
                Divider(color: colors.toasterBackground, height: 1),
                _MenuRow(label: 'Address Details', onTap: () => _openAddressDetails(context, account)),
                Divider(color: colors.toasterBackground, height: 1),
                _MenuRow(label: 'Show Recovery Phrase', onTap: () => _openRecoveryPhrase(context, account)),
              ],
            )
          : const Center(child: Text('Account not found')),
    );
  }

  Future<void> _openNameEditor(BuildContext context, WidgetRef ref, Account current) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => EditAccountScreen(initialAccount: current)));
    if (!context.mounted) return;
    ref.invalidate(accountsProvider);
  }

  void _openRecoveryPhrase(BuildContext context, Account account) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => RecoveryPhraseConfirmationScreen(walletIndex: account.walletIndex)));
  }

  void _openAddressDetails(BuildContext context, Account account) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => AccountDetailsScreen(account: account)));
  }
}

class _ProfileHeader extends StatelessWidget {
  final Account account;
  final AppColorsV2 colors;
  final AppTextTheme text;

  const _ProfileHeader({required this.account, required this.colors, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AccountBadge(
          account: account,
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
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _MenuRow({required this.label, this.value, required this.onTap});

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
