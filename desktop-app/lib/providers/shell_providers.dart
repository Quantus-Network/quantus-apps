import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/utils/send_strategies.dart';
import 'package:quantus_desktop_wallet/utils/serial_queue.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swap_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/send/send_flow.dart';
import 'package:wallet_core/utils/account_actions.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// Whether the sidebar is shown. The View menu hides and shows it.
final sidebarVisibleProvider = NotifierProvider<SidebarVisibilityNotifier, bool>(SidebarVisibilityNotifier.new);

class SidebarVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

/// The window's navigation, one step at a time: account switches and sheet
/// openings run in the order they were asked for, each once the ones before
/// it have finished. An account switch waits on the settings it is saved to,
/// so a shortcut pressed meanwhile acts on the account chosen before it.
final shellNavigationProvider = Provider<ShellNavigation>((ref) => ShellNavigation());

/// Runs the window's navigation one step at a time ([SerialQueue]), and can
/// drop the steps asked for so far: what was pressed while an account switch
/// waited was meant for that account, so when the switch fails it is not
/// done on another.
class ShellNavigation {
  final _queue = SerialQueue();

  /// Counts the cancellations; a step asked for before the last one is
  /// dropped when its turn comes.
  int _generation = 0;

  /// Runs [step] once the steps asked for before it have finished, unless
  /// [cancelPending] is called before it starts.
  Future<void> run(Future<void> Function() step) {
    final generation = _generation;
    return _queue.run(() async {
      if (generation == _generation) await step();
    });
  }

  /// Drops every step asked for so far that has not started.
  void cancelPending() => _generation++;
}

/// An account that could not be made the active account, and why. The shell
/// says so, then clears it.
final accountSwitchFailureProvider = NotifierProvider<AccountSwitchFailureNotifier, AccountSwitchFailure?>(
  AccountSwitchFailureNotifier.new,
);

typedef AccountSwitchFailure = ({DisplayAccount account, Object error});

class AccountSwitchFailureNotifier extends Notifier<AccountSwitchFailure?> {
  @override
  AccountSwitchFailure? build() => null;

  void report(DisplayAccount account, Object error) => state = (account: account, error: error);

  void clear() => state = null;
}

final sidebarSelectionProvider = NotifierProvider<SidebarSelectionNotifier, SidebarSelection>(
  SidebarSelectionNotifier.new,
);

class SidebarSelectionNotifier extends Notifier<SidebarSelection> {
  @override
  SidebarSelection build() => SidebarSelection.account;

  /// Selects [selection], after the navigation asked for before
  /// ([shellNavigationProvider]).
  Future<void> select(SidebarSelection selection) => ref.read(shellNavigationProvider).run(() async {
    if (!ref.mounted || _isUnderSheet) return;
    state = selection;
  });

  /// Makes [account] the active account and selects it, after the
  /// navigation asked for before ([shellNavigationProvider]).
  Future<void> showAccount(DisplayAccount account) => ref.read(shellNavigationProvider).run(() => _show(account));

  /// Selects the row [rows] down from the one selected when the navigation
  /// asked for before has finished ([shellNavigationProvider]), going round
  /// at the ends. The rows are the accounts, then Mining Rewards.
  Future<void> move(int rows) => ref.read(shellNavigationProvider).run(() => _move(rows));

  /// Whether a sheet opened since this switch was asked for: a sheet is for
  /// the account it opened on, so nothing moves under it.
  bool get _isUnderSheet => ref.read(shellSheetProvider) != null;

  Future<void> _show(DisplayAccount account) async {
    if (!ref.mounted || _isUnderSheet) return;
    try {
      await ref.read(activeAccountProvider.notifier).switchActiveAccount(account);
    } catch (e) {
      quantusPrint('Switching to ${account.account.name} failed: $e');
      if (!ref.mounted) return;
      // What was pressed while the switch waited was meant for [account].
      ref.read(shellNavigationProvider).cancelPending();
      ref.read(accountSwitchFailureProvider.notifier).report(account, e);
      return;
    }
    if (!ref.mounted) return;
    state = SidebarSelection.account;
  }

  Future<void> _move(int rows) async {
    if (!ref.mounted || _isUnderSheet) return;
    final accounts = ref.read(sidebarAccountsProvider);
    final activeId = ref.read(activeAccountProvider).value?.account.accountId;
    final selected = state == SidebarSelection.miningRewards
        ? accounts.length
        : accounts.indexWhere((account) => account.account.accountId == activeId);
    // With no account active yet, the walk starts from outside the list.
    final from = selected >= 0 ? selected : (rows > 0 ? -1 : 0);
    final to = (from + rows) % (accounts.length + 1);
    if (to == accounts.length) {
      state = SidebarSelection.miningRewards;
    } else {
      await _show(accounts[to]);
    }
  }
}

/// The accounts in the order the sidebar lists them; none until they have
/// loaded.
final sidebarAccountsProvider = Provider<List<DisplayAccount>>((ref) {
  final accounts = ref.watch(accountsProvider).value;
  final multisigs = ref.watch(multisigAccountsProvider).value;
  if (accounts == null || multisigs == null) return const [];
  return accountsInSidebarOrder(groupWallets(accounts: accounts, multisigs: multisigs));
});

/// The sheet over the window, or null when there is none.
final shellSheetProvider = NotifierProvider<ShellSheetNotifier, ShellSheet?>(ShellSheetNotifier.new);

class ShellSheetNotifier extends Notifier<ShellSheet?> {
  @override
  ShellSheet? build() => null;

  /// Presents [sheet] on the account chosen by the navigation asked for
  /// before ([shellNavigationProvider]). A sheet is modal to the window, so a
  /// request made while one is open does nothing.
  Future<void> open(ShellSheet sheet) => ref.read(shellNavigationProvider).run(() async => _open(sheet));

  void _open(ShellSheet sheet) {
    if (!ref.mounted || state != null) return;
    if (sheet == ShellSheet.send) _beginSend();
    state = sheet;
  }

  /// Send's flow starts with the press that opens it, a first fee quote with
  /// it: the sheet must not write a provider while it is being built.
  void _beginSend() {
    final strategy = sendStrategyFor(ref.read(activeAccountProvider).value);
    if (strategy == null) throw StateError('Send was opened on an account this app cannot send from.');
    beginSendFlow(ref.read, strategy);
  }

  /// Called by the shell once the sheet has left the screen.
  void closed() => state = null;
}

/// What the active account offers, for the toolbar and the Account menu alike.
/// Send is unavailable where this app cannot send yet ([sendStrategyFor]).
final activeAccountActionsProvider = Provider<List<AccountAction>>((ref) {
  final active = ref.watch(activeAccountProvider).value;
  if (active == null) return const [];
  final canSend = sendStrategyFor(active) != null;
  return [
    for (final action in accountActions(
      active,
      swapAvailable: ref.watch(remoteConfigProvider).swapAvailable,
      hasActiveSwap: ref.watch(activeSwapProvider) != null,
    ))
      if (action.kind == AccountActionKind.send && !canSend)
        const AccountAction(AccountActionKind.send, isEnabled: false)
      else
        action,
  ];
});
