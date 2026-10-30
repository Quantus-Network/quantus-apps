import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/menu_row.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_actions.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';
import 'package:resonance_network_wallet/v2/components/private_activity_notice.dart';

class AccountMenuScreen extends ConsumerWidget {
  final Account initialAccount;

  /// When true, this screen is shown right after creating an account: it shows a
  /// Done button (instead of a back button) that returns to the accounts list.
  final bool isPostCreation;

  const AccountMenuScreen({super.key, required this.initialAccount, this.isPostCreation = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    final accounts = ref.watch(accountsProvider);
    final account = accounts.value?.firstWhereOrNull((a) => a.accountId == initialAccount.accountId) ?? initialAccount;
    final isEncrypted = account.accountType == AccountType.encrypted;
    final canShowRecoveryPhrase = account.accountType == AccountType.local;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.accountMenuTitle, showBackButton: !isPostCreation),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _ProfileHeader(account: account),
          const SizedBox(height: 68),
          MenuRow(
            label: l10n.accountMenuAccountName,
            value: account.name,
            onTap: isEncrypted ? null : () => openAccountNameEditor(context, ref, account),
          ),
          const SizedBox(height: 4),
          const MenuDivider(),
          const SizedBox(height: 12),
          if (isEncrypted)
            MenuRow(label: l10n.accountMenuInnerHash, onTap: () => openInnerHash(context, account))
          else
            MenuRow(label: l10n.accountMenuAddressDetails, onTap: () => openAddressDetails(context, account)),
          if (canShowRecoveryPhrase) ...[
            const SizedBox(height: 4),
            const MenuDivider(),
            const SizedBox(height: 12),
            MenuRow(label: l10n.accountMenuShowRecoveryPhrase, onTap: () => openRecoveryPhrase(context, account)),
          ],
        ],
      ),
      bottomContent: _buildBottomContent(context, ref, l10n, account),
    );
  }

  Widget? _buildBottomContent(BuildContext context, WidgetRef ref, AppLocalizations l10n, Account account) {
    if (isPostCreation) {
      return ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.accountMenuDone,
          onTap: () => returnToAccountsScreen(context, ref, highlightAccountId: account.accountId),
        ),
      );
    }
    if (!canDisconnectAccount(ref, account)) return null;
    return ScaffoldBaseBottomContent(
      child: QuantusButton.simple(
        label: l10n.accountMenuDisconnect,
        variant: ButtonVariant.danger,
        onTap: () => disconnectAccount(context, ref, account),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Account account;

  const _ProfileHeader({required this.account});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      children: [
        if (account.accountType == AccountType.encrypted)
          const EncryptedLockBadge(size: 96)
        else
          AccountBadge.account(account: account, isActive: true, size: 96, textStyle: text.titleHero),
        const SizedBox(height: 12),
        Text(
          account.name,
          style: text.titleHero.copyWith(color: colors.textContent),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
