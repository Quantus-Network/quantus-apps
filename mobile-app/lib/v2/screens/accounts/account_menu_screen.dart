import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/accounts_grouping.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/account_badge.dart';
import 'package:resonance_network_wallet/v2/components/menu_row.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_details_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';
import 'package:resonance_network_wallet/v2/components/private_activity_notice.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/edit_account_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/inner_hash_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_confirmation_screen.dart';

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
            onTap: isEncrypted ? null : () => _openNameEditor(context, ref, account),
          ),
          const SizedBox(height: 4),
          const MenuDivider(),
          const SizedBox(height: 12),
          if (isEncrypted)
            MenuRow(label: l10n.accountMenuInnerHash, onTap: () => _openInnerHash(context, account))
          else
            MenuRow(label: l10n.accountMenuAddressDetails, onTap: () => _openAddressDetails(context, account)),
          if (canShowRecoveryPhrase) ...[
            const SizedBox(height: 4),
            const MenuDivider(),
            const SizedBox(height: 12),
            MenuRow(label: l10n.accountMenuShowRecoveryPhrase, onTap: () => _openRecoveryPhrase(context, account)),
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
    if (!_canDisconnect(ref, account)) return null;
    return ScaffoldBaseBottomContent(
      child: QuantusButton.simple(
        label: l10n.accountMenuDisconnect,
        variant: ButtonVariant.danger,
        onTap: () => _onDisconnect(context, ref, account),
      ),
    );
  }

  /// Hardware accounts can always be disconnected. Software accounts can be
  /// disconnected, except the last remaining account of the primary wallet
  /// (index 0) — that wallet can only be removed by logging out.
  bool _canDisconnect(WidgetRef ref, Account account) {
    if (account.accountType == AccountType.keystone) return true;
    if (account.accountType != AccountType.local) return false;
    if (account.walletIndex == 0) return !_isLastInWallet(ref, account);
    return true;
  }

  bool _isLastInWallet(WidgetRef ref, Account account) {
    final all = ref.read(accountsProvider).value ?? <Account>[];
    final siblings = all.where((a) => a.walletIndex == account.walletIndex && a.accountType != AccountType.encrypted);
    return siblings.length <= 1;
  }

  Future<void> _onDisconnect(BuildContext context, WidgetRef ref, Account account) {
    if (account.accountType == AccountType.keystone) {
      return _onDisconnectHardware(context, ref, account);
    }
    return _onDisconnectSoftware(context, ref, account);
  }

  Future<void> _onDisconnectHardware(BuildContext context, WidgetRef ref, Account account) async {
    final l10n = ref.read(l10nProvider);
    final confirmed = await showConfirmActionSheet(
      context,
      title: l10n.accountMenuDisconnectHardwareTitle,
      message: l10n.accountMenuDisconnectHardwareMessage(account.name),
      confirmLabel: l10n.accountMenuDisconnect,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _performRemoveAccount(context, ref, account);
  }

  /// Disconnecting a software account removes just that account, unless it is
  /// the last account in its wallet — in which case it removes the entire
  /// wallet (and its recovery phrase) after a second confirmation.
  Future<void> _onDisconnectSoftware(BuildContext context, WidgetRef ref, Account account) async {
    final l10n = ref.read(l10nProvider);
    final allAccounts = ref.read(accountsProvider).value ?? <Account>[];

    if (!_isLastInWallet(ref, account)) {
      final confirmed = await showConfirmActionSheet(
        context,
        title: l10n.accountMenuDisconnectAccountTitle,
        message: l10n.accountMenuDisconnectAccountMessage(account.name),
        confirmLabel: l10n.accountMenuDisconnect,
        cancelLabel: l10n.commonCancel,
        isDestructive: true,
      );
      if (!confirmed || !context.mounted) return;
      await _performRemoveAccount(context, ref, account);
      return;
    }

    final walletNumber = softwareWalletNumber(allAccounts, account.walletIndex) ?? account.walletIndex;
    final confirmWallet = await showConfirmActionSheet(
      context,
      title: l10n.accountMenuDisconnectWalletTitle(walletNumber),
      message: l10n.accountMenuDisconnectWalletMessage(account.name, walletNumber),
      confirmLabel: l10n.accountMenuDisconnectWalletConfirm,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmWallet || !context.mounted) return;

    final confirmDelete = await showConfirmActionSheet(
      context,
      title: l10n.accountMenuDeleteWalletTitle,
      message: l10n.accountMenuDeleteWalletMessage(walletNumber),
      confirmLabel: l10n.accountMenuDeleteWalletConfirm,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
    );
    if (!confirmDelete || !context.mounted) return;

    await _performRemoveWallet(context, ref, account.walletIndex);
  }

  Future<void> _performRemoveAccount(BuildContext context, WidgetRef ref, Account account) async {
    final l10n = ref.read(l10nProvider);
    try {
      await AccountsService().removeAccount(account);
      invalidateAccountProviders(ref);
      if (context.mounted) returnToAccountsScreen(context, ref);
    } catch (e, st) {
      quantusPrint('[AccountMenu] disconnect account error: $e\n$st');
      if (context.mounted) context.showErrorToaster(message: l10n.accountMenuDisconnectError);
    }
  }

  Future<void> _performRemoveWallet(BuildContext context, WidgetRef ref, int walletIndex) async {
    final l10n = ref.read(l10nProvider);
    try {
      await AccountsService().removeWallet(walletIndex);
      invalidateAccountProviders(ref);
      if (context.mounted) returnToAccountsScreen(context, ref);
    } catch (e, st) {
      quantusPrint('[AccountMenu] disconnect wallet error: $e\n$st');
      if (context.mounted) context.showErrorToaster(message: l10n.accountMenuDisconnectError);
    }
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
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => AccountDetailsScreen(accountId: account.accountId)));
  }

  void _openInnerHash(BuildContext context, Account account) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => InnerHashScreen(walletIndex: account.walletIndex)));
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
