import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/utils/accounts_grouping.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_details_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_navigation.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/edit_account_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/inner_hash_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/multisig_details_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_confirmation_screen.dart';

/// Account actions shared by the Accounts list menus and the account screens.

Future<void> _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));

Future<void> openAccountNameEditor(BuildContext context, WidgetRef ref, Account account) async {
  await _push(context, EditAccountScreen(initialAccount: account));
  if (context.mounted) ref.invalidate(accountsProvider);
}

Future<void> openMultisigNameEditor(BuildContext context, WidgetRef ref, MultisigAccount account) async {
  await _push(context, EditAccountScreen.multisig(initialMultisig: account));
  if (context.mounted) ref.invalidate(multisigAccountsProvider);
}

Future<void> openAddressDetails(BuildContext context, BaseAccount account) =>
    _push(context, AccountDetailsScreen(accountId: account.accountId));

Future<void> openInnerHash(BuildContext context, Account account) =>
    _push(context, InnerHashScreen(walletIndex: account.walletIndex));

Future<void> openRecoveryPhrase(BuildContext context, Account account) =>
    _push(context, RecoveryPhraseConfirmationScreen(walletIndex: account.walletIndex));

Future<void> openMultisigDetails(BuildContext context, MultisigAccount account) =>
    _push(context, MultisigDetailsScreen(account: account));

/// Hardware accounts can always be disconnected. Software accounts can be
/// disconnected, except the last remaining account of the primary wallet
/// (index 0) — that wallet can only be removed by logging out.
bool canDisconnectAccount(WidgetRef ref, Account account) {
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

Future<void> disconnectAccount(BuildContext context, WidgetRef ref, Account account) {
  if (account.accountType == AccountType.keystone) {
    return _disconnectHardware(context, ref, account);
  }
  return _disconnectSoftware(context, ref, account);
}

Future<void> _disconnectHardware(BuildContext context, WidgetRef ref, Account account) async {
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
  await _removeAccount(context, ref, account);
}

/// Disconnecting a software account removes just that account, unless it is
/// the last account in its wallet — in which case it removes the entire
/// wallet (and its recovery phrase) after a second confirmation.
Future<void> _disconnectSoftware(BuildContext context, WidgetRef ref, Account account) async {
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
    await _removeAccount(context, ref, account);
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

  await _removeWallet(context, ref, account.walletIndex);
}

Future<void> _removeAccount(BuildContext context, WidgetRef ref, Account account) async {
  final l10n = ref.read(l10nProvider);
  try {
    await AccountsService().removeAccount(account);
    invalidateAccountProviders(ref);
    if (context.mounted) returnToAccountsScreen(context, ref);
  } catch (e, st) {
    quantusPrint('[AccountActions] disconnect account error: $e\n$st');
    if (context.mounted) context.showErrorToaster(message: l10n.accountMenuDisconnectError);
  }
}

Future<void> _removeWallet(BuildContext context, WidgetRef ref, int walletIndex) async {
  final l10n = ref.read(l10nProvider);
  try {
    await AccountsService().removeWallet(walletIndex);
    invalidateAccountProviders(ref);
    if (context.mounted) returnToAccountsScreen(context, ref);
  } catch (e, st) {
    quantusPrint('[AccountActions] disconnect wallet error: $e\n$st');
    if (context.mounted) context.showErrorToaster(message: l10n.accountMenuDisconnectError);
  }
}

Future<void> disconnectMultisig(BuildContext context, WidgetRef ref, MultisigAccount account) async {
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
    if (context.mounted) returnToAccountsScreen(context, ref);
  } catch (e, st) {
    quantusPrint('[AccountActions] disconnect multisig error: $e\n$st');
    if (context.mounted) context.showErrorToaster(message: l10n.accountMenuDisconnectError);
  }
}
