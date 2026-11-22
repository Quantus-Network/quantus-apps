import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/models/sidebar_selection.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/utils/send_strategies.dart';
import 'package:quantus_desktop_wallet/utils/serial_queue.dart';
import 'package:quantus_desktop_wallet/utils/sidebar_order.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swap_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_flow.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/utils/account_actions.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// Whether the sidebar is shown. The View menu hides and shows it.
final sidebarVisibleProvider = NotifierProvider<SidebarVisibilityNotifier, bool>(SidebarVisibilityNotifier.new);

class SidebarVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

/// How wide the sidebar is, in points: what the person dragged it to, kept
/// for the next start.
final sidebarWidthProvider = NotifierProvider<SidebarWidthNotifier, double>(SidebarWidthNotifier.new);

class SidebarWidthNotifier extends SavedWidthNotifier {
  static const double initial = 240;
  static const double minimum = 200;
  static const double maximum = 360;

  /// Where the width is kept between runs.
  static const settingsKey = 'desktop_sidebar_width';

  @override
  double get startWidth => initial;

  @override
  double get minWidth => minimum;

  @override
  double get maxWidth => maximum;

  @override
  String get key => settingsKey;

  @override
  String get panelName => 'sidebar';
}

/// How wide a resizable panel is, in points: what the person dragged it to,
/// within [minWidth] and [maxWidth], kept for the next start under [key].
abstract class SavedWidthNotifier extends Notifier<double> {
  /// Its width on a first run.
  double get startWidth;

  double get minWidth;
  double get maxWidth;

  /// Where the width is kept between runs.
  String get key;

  /// What the panel is called in what is reported of it.
  String get panelName;

  @override
  double build() {
    final saved = ref.watch(settingsServiceProvider).getValue(key);
    if (saved == null) return startWidth;
    final width = saved is String ? double.tryParse(saved) : null;
    if (width == null || !width.isFinite) {
      // A preference of the window's, not the wallet's: it opens as it
      // would on a first run, and the stray value is reported.
      ref.read(telemetryProvider).sendError('The saved $panelName width is unreadable', error: saved);
      return startWidth;
    }
    return width.clamp(minWidth, maxWidth);
  }

  /// Makes the panel [width] wide, within [minWidth] and [maxWidth].
  void resizeTo(double width) => state = width.clamp(minWidth, maxWidth);

  /// Keeps the width it has now for the next start. A failure is reported:
  /// the panel keeps its width until the app quits.
  Future<void> save() async {
    final telemetry = ref.read(telemetryProvider);
    try {
      await ref.read(settingsServiceProvider).setString(key, '$state');
    } catch (e) {
      quantusPrint('Saving the $panelName width failed: $e');
      telemetry.sendError('Saving the $panelName width failed', error: e);
    }
  }
}

/// The window's navigation, one step at a time: account switches and sheet
/// openings run in the order they were asked for, each once the ones before
/// it have finished. An account switch waits on the settings it is saved to,
/// so a shortcut pressed meanwhile acts on the account chosen before it.
final shellNavigationProvider = NotifierProvider<ShellNavigation, bool>(ShellNavigation.new);

/// Runs the window's navigation one step at a time ([SerialQueue]), and can
/// drop the steps asked for so far: what was pressed while an account switch
/// waited was meant for that account, so when the switch fails it is not
/// done on another. Its state says whether any step is still to finish.
class ShellNavigation extends Notifier<bool> {
  final _queue = SerialQueue();

  /// Counts the cancellations; a step asked for before the last one is
  /// dropped when its turn comes.
  int _generation = 0;

  /// The steps asked for that have not finished.
  int _unfinished = 0;

  @override
  bool build() => false;

  /// Runs [step] once the steps asked for before it have finished, unless
  /// [cancelPending] is called before it starts.
  Future<void> run(Future<void> Function() step) {
    final generation = _generation;
    _unfinished++;
    state = true;
    return _queue.run(() async {
      try {
        if (generation == _generation) await step();
      } finally {
        _unfinished--;
        if (_unfinished == 0 && ref.mounted) state = false;
      }
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
  Future<void> select(SidebarSelection selection) => ref.read(shellNavigationProvider.notifier).run(() async {
    if (!ref.mounted || _isUnderSheet) return;
    state = selection;
  });

  /// Makes [account] the active account and selects it, after the
  /// navigation asked for before ([shellNavigationProvider]).
  Future<void> showAccount(DisplayAccount account) =>
      ref.read(shellNavigationProvider.notifier).run(() => _show(account));

  /// Makes [account] the active account and selects it, from a navigation
  /// step already running: [showAccount] would wait behind the steps asked
  /// for after it. A failure is reported as [showAccount]'s is.
  Future<void> showInStep(DisplayAccount account) => _show(account);

  /// Selects the row [rows] down from the one selected when the navigation
  /// asked for before has finished ([shellNavigationProvider]), going round
  /// at the ends. The rows are the accounts showing, then Mining Rewards.
  Future<void> move(int rows) => ref.read(shellNavigationProvider.notifier).run(() => _move(rows));

  /// Whether a sheet opened since this switch was asked for: a sheet is for
  /// the account it opened on, so nothing moves under it.
  bool get _isUnderSheet => ref.read(shellSheetProvider) != null;

  Future<void> _show(DisplayAccount account) async {
    if (!ref.mounted || _isUnderSheet) return;
    // Before the switch, so the wallet being left never closes under the
    // rows around the one clicked.
    if (ref.read(activeWalletIndexProvider) case final wallet?) {
      ref.read(keptOpenWalletsProvider.notifier).keepOpen(wallet);
    }
    try {
      await ref.read(activeAccountProvider.notifier).switchActiveAccount(account);
    } catch (e) {
      quantusPrint('Switching to ${account.account.name} failed: $e');
      if (!ref.mounted) return;
      // What was pressed while the switch waited was meant for [account].
      ref.read(shellNavigationProvider.notifier).cancelPending();
      ref.read(accountSwitchFailureProvider.notifier).report(account, e);
      return;
    }
    if (!ref.mounted) return;
    state = SidebarSelection.account;
  }

  Future<void> _move(int rows) async {
    if (!ref.mounted || _isUnderSheet) return;
    final accounts = ref.read(visibleSidebarAccountsProvider);
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
  Future<void> open(ShellSheet sheet) => ref.read(shellNavigationProvider.notifier).run(() async => _open(sheet));

  /// Presents [sheet] now, from a navigation step already running
  /// ([shellNavigationProvider]): [open] would wait behind the steps asked
  /// for after it, an account switch among them.
  void openInStep(ShellSheet sheet) => _open(sheet);

  void _open(ShellSheet sheet) {
    if (!ref.mounted || state != null) return;
    // Asked for while an account switch waited, it is checked against the
    // account the switch ended on.
    if (!_isOffered(sheet)) {
      quantusPrint('${sheet.name} is not offered on the active account; nothing is opened.');
      return;
    }
    if (sheet == ShellSheet.send || sheet == ShellSheet.propose) _beginSend();
    state = sheet;
  }

  /// Whether the active account offers [sheet]; a sheet that does not act
  /// on an account always is.
  bool _isOffered(ShellSheet sheet) {
    final kind = switch (sheet) {
      ShellSheet.receive => AccountActionKind.receive,
      ShellSheet.send => AccountActionKind.send,
      ShellSheet.propose => AccountActionKind.propose,
      ShellSheet.swap => AccountActionKind.swap,
      ShellSheet.settings || ShellSheet.accountInfo => null,
    };
    if (kind == null) return true;
    return ref.read(activeAccountActionsProvider).any((action) => action.kind == kind && action.isEnabled);
  }

  /// A send's flow, a proposal's too, starts with the press that opens its
  /// sheet, a first fee quote with it: the sheet must not write a provider
  /// while it is being built.
  void _beginSend() {
    final strategy = sendStrategyFor(
      ref.read(activeAccountProvider).value,
      accounts: ref.read(accountsProvider).value ?? const [],
    );
    if (strategy == null) throw StateError('A send was opened on an account this app cannot send from.');
    beginSendFlow(ref.read, strategy);
  }

  /// Called by the shell once the sheet has left the screen.
  void closed() => state = null;
}

/// What the active account offers, for the toolbar and the Account menu alike.
/// Send, and Propose on a multisig, are unavailable where this app cannot
/// make the send ([sendStrategyFor]).
final activeAccountActionsProvider = Provider<List<AccountAction>>((ref) {
  final active = ref.watch(activeAccountProvider).value;
  if (active == null) return const [];
  final canSend = sendStrategyFor(active, accounts: ref.watch(accountsProvider).value ?? const []) != null;
  bool sends(AccountActionKind kind) => kind == AccountActionKind.send || kind == AccountActionKind.propose;
  return [
    for (final action in accountActions(
      active,
      swapAvailable: ref.watch(remoteConfigProvider).swapAvailable,
      hasActiveSwap: ref.watch(activeSwapProvider) != null,
    ))
      if (sends(action.kind) && !canSend) AccountAction(action.kind, isEnabled: false) else action,
  ];
});

/// The account actions as the menus and their shortcuts offer them. While
/// navigation asked for earlier is still to finish, the account it ends on
/// is not known yet, so Receive, Send and Propose are offered whatever the
/// active account allows, and checked against the account they open on
/// ([ShellSheetNotifier.open]). The toolbar shows what the active account
/// offers ([activeAccountActionsProvider]).
final menuAccountActionsProvider = Provider<List<AccountAction>>((ref) {
  final actions = ref.watch(activeAccountActionsProvider);
  if (!ref.watch(shellNavigationProvider)) return actions;
  const whatever = [AccountActionKind.receive, AccountActionKind.send, AccountActionKind.propose];
  return [
    for (final kind in whatever) AccountAction(kind),
    for (final action in actions)
      if (!whatever.contains(action.kind)) action,
  ];
});
