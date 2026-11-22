import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/remote_notifications_registration.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/utils/wallet_names.dart';
import 'package:wallet_core/utils/account_menu.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// What can be copied from an account's menu.
enum CopiedValue { address, innerHash }

/// One thing an account's menu does, as the menu bar's Account menu asks
/// for it on the active account ([AccountManager.runOnActive]).
enum AccountAction { getInfo, copyAddress, copyInnerHash, rename, showRecoveryPhrase, showSigners, disconnect }

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

/// What is being renamed in the sidebar: an account's row, or a wallet's
/// heading, which shows a name field in place of its name.
@immutable
sealed class RenameTarget {
  const RenameTarget();
}

final class RenameAccount extends RenameTarget {
  const RenameAccount(this.accountId);

  final String accountId;

  @override
  bool operator ==(Object other) => other is RenameAccount && other.accountId == accountId;

  @override
  int get hashCode => accountId.hashCode;
}

final class RenameWallet extends RenameTarget {
  const RenameWallet(this.walletIndex);

  final int walletIndex;

  @override
  bool operator ==(Object other) => other is RenameWallet && other.walletIndex == walletIndex;

  @override
  int get hashCode => walletIndex.hashCode;
}

/// The name being typed over in the sidebar, if any. One at a time: starting
/// another ends the first, which keeps what was typed as it loses the focus.
final sidebarRenameProvider = NotifierProvider<SidebarRenameNotifier, RenameTarget?>(SidebarRenameNotifier.new);

class SidebarRenameNotifier extends Notifier<RenameTarget?> {
  @override
  RenameTarget? build() => null;

  void start(RenameTarget target) => state = target;

  /// Ends renaming [target], unless another rename has started since.
  void end(RenameTarget target) {
    if (state == target) state = null;
  }
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

/// A software wallet: what it is called, and its accounts' names.
typedef SoftwareWallet = ({int walletIndex, String name, List<String> accounts});

/// The software wallets, whose recovery phrases this app holds, in the
/// sidebar's order: what each is called, and its accounts' names.
final softwareWalletsProvider = Provider<List<SoftwareWallet>>((ref) {
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

  /// Whether the providers it works on are still there: false once the app
  /// that held them has gone, as when the window closes while a name is
  /// being typed.
  bool get isMounted => _ref.mounted;

  /// Opens the Info sheet on [account], at [start]. Like any sheet, it does
  /// not open over another.
  Future<void> openInfo(BaseAccount account, {AccountInfoStart start = AccountInfoStart.info}) {
    _ref.read(accountInfoTargetProvider.notifier).set(AccountInfoTarget(account.accountId, start: start));
    return _ref.read(shellSheetProvider.notifier).open(ShellSheet.accountInfo);
  }

  /// Starts renaming [account]: in its row when the sidebar shows, or else
  /// in Get Info, on its name.
  Future<void> startRename(BaseAccount account) async {
    if (!_ref.read(sidebarVisibleProvider)) return openInfo(account, start: AccountInfoStart.rename);
    _ref.read(sidebarRenameProvider.notifier).start(RenameAccount(account.accountId));
  }

  /// Starts renaming the wallet at [walletIndex], in its heading.
  void startRenameWallet(int walletIndex) => _ref.read(sidebarRenameProvider.notifier).start(RenameWallet(walletIndex));

  /// Names the wallet at [walletIndex] [entered], trimmed. A blank name
  /// clears its own name, so it is called by its number again, as on the
  /// phone; the name it is shown by, unchanged, is not written. A write that
  /// fails is thrown.
  Future<void> renameWallet(int walletIndex, String entered) async {
    final name = entered.trim();
    if (name.isEmpty) {
      if (_ref.read(walletNameProvider(walletIndex)) == null) return;
    } else if (name == _ref.read(walletLabelProvider(walletIndex))) {
      return;
    }
    await _ref.read(settingsServiceProvider).setWalletName(walletIndex, name.isEmpty ? null : name);
    _ref.invalidate(walletNameProvider(walletIndex));
  }

  /// Adds a Transparent account to the software wallet at [walletIndex],
  /// after the navigation asked for before, one at a time so two never take
  /// the same slot. It becomes the active account with its name ready to be
  /// typed over. One that cannot be added says so on the active account.
  Future<void> createAccount(int walletIndex) =>
      _ref.read(shellNavigationProvider.notifier).run(() => _create(walletIndex));

  /// [createAccount] in the wallet of the account active when its turn comes,
  /// as ⌘N is meant for the account a switch still being saved ends on. With
  /// no software wallet to add to, as on a Cold Wallet account, nothing is done.
  Future<void> createInActiveWallet() => _ref.read(shellNavigationProvider.notifier).run(() async {
    if (!_ref.mounted) return;
    final activeId = _ref.read(activeAccountProvider).value?.account.accountId;
    final WalletGroup? wallet;
    try {
      // From storage: the list may still be reloading after the last one added.
      final accounts = await _ref.read(accountsServiceProvider).getAccounts();
      final multisigs = _ref.read(multisigAccountsProvider).value ?? const <MultisigAccount>[];
      wallet = groupWallets(
        accounts: accounts,
        multisigs: multisigs,
      ).wallets.where((w) => activeId != null && w.contains(activeId)).firstOrNull;
    } catch (e) {
      _noteNotAdded(e);
      return;
    }
    if (wallet == null || wallet.kind != WalletKind.software) {
      quantusPrint('The active account is in no software wallet; no account is added.');
      return;
    }
    await _create(wallet.walletIndex);
  });

  Future<void> _create(int walletIndex) async {
    // A sheet is for the account it opened on, so nothing moves under it.
    if (!_ref.mounted || _ref.read(shellSheetProvider) != null) return;
    final l10n = _ref.read(l10nProvider);
    final service = _ref.read(accountsServiceProvider);
    final Account account;
    try {
      final accounts = await service.getAccounts();
      if (accounts.any((a) => a.walletIndex == walletIndex && a.accountType == AccountType.keystone)) {
        throw StateError('Wallet $walletIndex is a hardware wallet');
      }
      final draft = await service.createNewAccount(walletIndex: walletIndex);
      account = draft.copyWith(name: l10n.createAccountDefaultName(accounts.length + 1));
      await service.addAccount(account);
    } catch (e) {
      _noteNotAdded(e);
      return;
    }
    if (!_ref.mounted) return;

    _ref.read(keptOpenWalletsProvider.notifier).keepOpen(walletIndex);
    // Before the list reloads: the switch reads which wallet is being left.
    await _ref.read(sidebarSelectionProvider.notifier).showInStep(RegularAccount(account));
    if (!_ref.mounted) return;
    _ref.invalidate(accountsProvider);
    unawaited(registerForRemoteNotificationsBestEffort(_ref.read, insertAddress: account.accountId));

    // A switch that failed has said so, and the account is there all the same.
    if (_ref.read(activeAccountProvider).value?.account.accountId != account.accountId) return;
    if (_ref.read(sidebarVisibleProvider)) {
      _ref.read(sidebarRenameProvider.notifier).start(RenameAccount(account.accountId));
    } else {
      _ref
          .read(accountInfoTargetProvider.notifier)
          .set(AccountInfoTarget(account.accountId, start: AccountInfoStart.rename));
      _ref.read(shellSheetProvider.notifier).openInStep(ShellSheet.accountInfo);
    }
  }

  void _noteNotAdded(Object error) {
    quantusPrint('Adding an account failed: $error');
    if (!_ref.mounted) return;
    final active = _ref.read(activeAccountProvider).value?.account;
    if (active == null) return;
    _ref
        .read(accountNoteProvider.notifier)
        .show(
          AccountNote(
            accountId: active.accountId,
            message: _ref.read(l10nProvider).createAccountErrorCouldNotAdd,
            isError: true,
          ),
        );
  }

  /// Does [action] on the account active once the navigation asked for
  /// before has finished, as Receive and Send open on it: a shortcut pressed
  /// while an account switch is being saved is meant for the account switched
  /// to. Nothing is done when that account's menu does not offer [action], or
  /// when the switch failed ([ShellNavigation.cancelPending]); a sheet does
  /// not open over another.
  Future<void> runOnActive(AccountAction action) => _ref.read(shellNavigationProvider.notifier).run(() async {
    if (!_ref.mounted) return;
    final account = _ref.read(activeAccountProvider).value?.account;
    final accounts = _ref.read(accountsProvider).value;
    if (account == null || accounts == null || !_offers(account, accounts, action)) {
      quantusPrint('${action.name} is not offered on the active account; nothing is done.');
      return;
    }
    void showInfo(AccountInfoStart start) {
      _ref.read(accountInfoTargetProvider.notifier).set(AccountInfoTarget(account.accountId, start: start));
      _ref.read(shellSheetProvider.notifier).openInStep(ShellSheet.accountInfo);
    }

    switch (action) {
      case AccountAction.getInfo || AccountAction.showSigners:
        showInfo(AccountInfoStart.info);
      case AccountAction.copyAddress:
        await copy(account, CopiedValue.address);
      case AccountAction.copyInnerHash:
        await copy(account, CopiedValue.innerHash);
      case AccountAction.rename:
        // As [startRename]: in its row when the sidebar shows.
        if (_ref.read(sidebarVisibleProvider)) {
          _ref.read(sidebarRenameProvider.notifier).start(RenameAccount(account.accountId));
        } else {
          showInfo(AccountInfoStart.rename);
        }
      case AccountAction.showRecoveryPhrase:
        showInfo(AccountInfoStart.recoveryPhrase);
      case AccountAction.disconnect:
        showInfo(AccountInfoStart.disconnect);
    }
  });

  /// Whether [account]'s menu offers [action], by wallet_core's rules. An
  /// account no longer among [accounts], as just after a change, offers none.
  static bool _offers(BaseAccount account, List<Account> accounts, AccountAction action) {
    final items = switch (account) {
      final Account account when accounts.any((a) => a.accountId == account.accountId) => accountMenuOf(
        account,
        accounts,
      ),
      MultisigAccount() => multisigMenu,
      _ => const <AccountMenuItem>[],
    };
    return switch (action) {
      AccountAction.getInfo => items.contains(AccountMenuItem.showAddress) || items.contains(AccountMenuItem.innerHash),
      AccountAction.copyAddress => items.contains(AccountMenuItem.showAddress),
      AccountAction.copyInnerHash => items.contains(AccountMenuItem.innerHash),
      AccountAction.rename => items.contains(AccountMenuItem.rename),
      AccountAction.showRecoveryPhrase => items.contains(AccountMenuItem.recoveryPhrase),
      AccountAction.showSigners => items.contains(AccountMenuItem.multisigDetails),
      AccountAction.disconnect => items.contains(AccountMenuItem.disconnect),
    };
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
            _ref.read(keptOpenWalletsProvider.notifier).forget(walletIndex);
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
