import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/utils/wallet_names.dart';
import 'package:wallet_core/utils/account_menu.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// What can be copied from an account's menu.
enum CopiedValue { address, innerHash }

/// A short note about an account, shown on its own row, as the HIG has
/// status shown by what it is about: "Address copied", or why a copy failed.
class AccountNote {
  const AccountNote({required this.accountId, required this.message, required this.isError});

  final String accountId;
  final String message;
  final bool isError;
}

/// The note showing, if any. One shows at a time: a new one replaces it.
final accountNoteProvider = NotifierProvider<AccountNoteNotifier, AccountNote?>(AccountNoteNotifier.new);

class AccountNoteNotifier extends Notifier<AccountNote?> {
  /// How long a note shows; a failure shows longer, to be read.
  static const shownFor = Duration(milliseconds: 1500);
  static const failureShownFor = Duration(seconds: 4);

  Timer? _clear;

  @override
  AccountNote? build() {
    ref.onDispose(() => _clear?.cancel());
    return null;
  }

  void show(AccountNote note) {
    _clear?.cancel();
    state = note;
    _clear = Timer(note.isError ? failureShownFor : shownFor, () => state = null);
  }
}

/// Where the Info sheet opens: on the account's details, with its name ready
/// to be typed over, or straight on its recovery phrase or on disconnecting.
enum AccountInfoStart { info, rename, recoveryPhrase, disconnect }

/// The account the Info sheet is about, which need not be the active one,
/// and where it opens.
class AccountInfoTarget {
  const AccountInfoTarget(this.accountId, {this.start = AccountInfoStart.info});

  final String accountId;
  final AccountInfoStart start;
}

/// What the Info sheet opens on. It is set before the sheet opens, and the
/// sheet reads it once.
final accountInfoTargetProvider = NotifierProvider<AccountInfoTargetNotifier, AccountInfoTarget?>(
  AccountInfoTargetNotifier.new,
);

class AccountInfoTargetNotifier extends Notifier<AccountInfoTarget?> {
  @override
  AccountInfoTarget? build() => null;

  void set(AccountInfoTarget target) => state = target;
}

/// The wallet whose recovery phrase Settings opens on, when it is opened for
/// one: Settings takes it on opening, and clears it.
final recoveryPhraseTargetProvider = NotifierProvider<RecoveryPhraseTargetNotifier, int?>(
  RecoveryPhraseTargetNotifier.new,
);

class RecoveryPhraseTargetNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int walletIndex) => state = walletIndex;

  void clear() => state = null;
}

/// The software wallets, whose recovery phrases this app holds, in the
/// sidebar's order: what each is called, and its accounts' names.
final softwareWalletsProvider = Provider<List<({int walletIndex, String name, List<String> accounts})>>((ref) {
  final l10n = ref.watch(l10nProvider);
  final grouping = groupWallets(
    accounts: ref.watch(accountsProvider).value ?? const [],
    multisigs: ref.watch(multisigAccountsProvider).value ?? const [],
  );
  return [
    for (final wallet in grouping.wallets)
      if (wallet.kind == WalletKind.software)
        (
          walletIndex: wallet.walletIndex,
          name: walletDisplayName(l10n, wallet, ref.watch(walletNameProvider(wallet.walletIndex))),
          accounts: [
            for (final account in wallet.accounts) account.name,
            if (wallet.encryptedAccount case final encrypted?) encrypted.name,
          ],
        ),
  ];
});

/// What the wallet at [walletIndex] is called where it is named: its own
/// name, or "Wallet 2" / "Cold Wallet" by its number, as the sidebar's
/// headings say. Null while the accounts are being read, as after a change,
/// and once the wallet is gone, as just after it was disconnected.
final walletLabelProvider = Provider.family<String?, int>((ref, walletIndex) {
  final l10n = ref.watch(l10nProvider);
  final accounts = ref.watch(accountsProvider).value;
  final multisigs = ref.watch(multisigAccountsProvider).value;
  if (accounts == null || multisigs == null) return null;
  final grouping = groupWallets(accounts: accounts, multisigs: multisigs);
  final wallet = grouping.wallets.where((w) => w.walletIndex == walletIndex).firstOrNull;
  if (wallet == null) return null;
  return walletDisplayName(l10n, wallet, ref.watch(walletNameProvider(walletIndex)));
});

/// What the account menus and the Info sheet do to an account: copy from it,
/// rename it, disconnect it. The rules for what each account allows are
/// wallet_core's ([accountMenuOf], [disconnectPlanOf], [nameEditOf]); this
/// carries them out on the device's storage and refreshes what shows it.
final accountManagerProvider = Provider<AccountManager>(AccountManager.new);

class AccountManager {
  AccountManager(this._ref);

  final Ref _ref;

  /// Opens the Info sheet on [account], at [start]. Like any sheet, it does
  /// not open over another.
  Future<void> openInfo(BaseAccount account, {AccountInfoStart start = AccountInfoStart.info}) {
    _ref.read(accountInfoTargetProvider.notifier).set(AccountInfoTarget(account.accountId, start: start));
    return _ref.read(shellSheetProvider.notifier).open(ShellSheet.accountInfo);
  }

  /// Opens Settings on the recovery phrase of the wallet at [walletIndex].
  Future<void> openRecoveryPhrase(int walletIndex) {
    _ref.read(recoveryPhraseTargetProvider.notifier).set(walletIndex);
    return _ref.read(shellSheetProvider.notifier).open(ShellSheet.settings);
  }

  /// Copies [value] of [account] and notes it on the account's row. A copy
  /// that fails is noted as a failure, and the clipboard is left as it was.
  Future<void> copy(BaseAccount account, CopiedValue value) async {
    final l10n = _ref.read(l10nProvider);
    final notes = _ref.read(accountNoteProvider.notifier);
    try {
      final text = switch (value) {
        CopiedValue.address => account.accountId,
        CopiedValue.innerHash => await _innerHashOf(account),
      };
      await Clipboard.setData(ClipboardData(text: text));
    } catch (e) {
      quantusPrint('Copying from ${account.accountId} failed: $e');
      notes.show(
        AccountNote(accountId: account.accountId, message: l10n.desktopAccountCopyFailed(_reason(e)), isError: true),
      );
      return;
    }
    notes.show(
      AccountNote(
        accountId: account.accountId,
        message: switch (value) {
          CopiedValue.address => l10n.desktopAccountAddressCopied,
          CopiedValue.innerHash => l10n.desktopAccountInnerHashCopied,
        },
        isError: false,
      ),
    );
  }

  Future<String> _innerHashOf(BaseAccount account) async {
    if (account is! Account || account.accountType != AccountType.encrypted) {
      throw StateError('${account.accountId} has no inner hash');
    }
    final keyPair = await _ref.read(encryptedAccountServiceProvider(account.walletIndex)).receiveKeyPair();
    return keyPair.rewardsPreimageHex;
  }

  /// Renames [account] to [entered], trimmed. A blank or unchanged name is
  /// not written; what [entered] came to is returned either way. A write
  /// that fails is thrown.
  Future<NameEdit> rename(BaseAccount account, String entered) async {
    final edit = nameEditOf(account.name, entered);
    if (edit case NameChanged(:final name)) {
      switch (account) {
        case Account():
          await _ref.read(accountsServiceProvider).updateAccountName(account, name);
          _refreshAccounts();
        case MultisigAccount():
          await _ref.read(multisigAccountsProvider.notifier).updateName(account, name);
          _ref.invalidate(activeAccountProvider);
        default:
          throw StateError('${account.accountId} cannot be renamed');
      }
    }
    return edit;
  }

  /// Disconnects [account] as [disconnectPlanOf] has it, or a multisig.
  /// Asking first, and asking for approval to delete a wallet, is the
  /// caller's. A removal that fails is thrown, and nothing changes.
  Future<void> disconnect(BaseAccount account) async {
    switch (account) {
      case MultisigAccount():
        await _ref.read(multisigAccountsProvider.notifier).remove(account.accountId);
        _ref.invalidate(activeAccountProvider);
      case Account():
        final service = _ref.read(accountsServiceProvider);
        switch (disconnectPlanOf(account, _ref.read(accountsProvider).requireValue)) {
          case DisconnectAccount() || DisconnectHardware():
            await service.removeAccount(account);
          case DisconnectWallet(:final walletIndex):
            await service.removeWallet(walletIndex);
          case null:
            throw StateError('${account.accountId} cannot be disconnected');
        }
        _refreshAccounts();
      default:
        throw StateError('${account.accountId} cannot be disconnected');
    }
  }

  /// The accounts and the active one are read again, as after any change to
  /// them ([invalidateAccountProviders]).
  void _refreshAccounts() {
    _ref.invalidate(accountsProvider);
    _ref.invalidate(activeAccountProvider);
  }

  static String _reason(Object error) => switch (error) {
    PlatformException(:final message?) => message,
    _ => '$error',
  };
}
