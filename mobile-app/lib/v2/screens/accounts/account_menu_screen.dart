import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/accounts_grouping.dart';
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
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_confirmation_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AccountMenuScreen extends ConsumerWidget {
  final Account initialAccount;

  /// When true, this screen is shown right after creating an account: it shows a
  /// Done button (instead of a back button) that returns to the accounts list.
  final bool isPostCreation;

  const AccountMenuScreen({super.key, required this.initialAccount, this.isPostCreation = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;

    final accounts = ref.watch(accountsProvider);
    final account = accounts.value?.firstWhereOrNull((a) => a.accountId == initialAccount.accountId) ?? initialAccount;
    final canShowRecoveryPhrase = account.accountType == AccountType.local;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.accountMenuTitle, showBackButton: !isPostCreation),
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
          if (canShowRecoveryPhrase) ...[
            const MenuDivider(),
            _MenuRow(label: l10n.accountMenuShowRecoveryPhrase, onTap: () => _openRecoveryPhrase(context, account)),
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
          onTap: () => returnToAccountsSheet(context, ref, highlightAccountId: account.accountId),
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
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
      if (context.mounted) returnToAccountsSheet(context, ref);
    } catch (e, st) {
      quantusDebugPrint('[AccountMenu] disconnect account error: $e\n$st');
      if (context.mounted) context.showErrorToaster(message: l10n.accountMenuDisconnectError);
    }
  }

  Future<void> _performRemoveWallet(BuildContext context, WidgetRef ref, int walletIndex) async {
    final l10n = ref.read(l10nProvider);
    try {
      await AccountsService().removeWallet(walletIndex);
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
      if (context.mounted) returnToAccountsSheet(context, ref);
    } catch (e, st) {
      quantusDebugPrint('[AccountMenu] disconnect wallet error: $e\n$st');
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
        AccountBadge.account(
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
