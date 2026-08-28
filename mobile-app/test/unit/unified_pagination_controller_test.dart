import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/controllers/unified_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

import '../fakes.dart';

/// Records the scope of every fetch, and optionally holds them open so
/// overlapping callers are still in flight when the next one arrives.
class _FakeHistoryService extends ChainHistoryService {
  final List<List<String>> scopes = [];
  Completer<void>? gate;

  int get calls => scopes.length;

  @override
  Future<SortedTransactionsList> fetchAllTransactionTypes({
    required List<String> accountIds,
    int limit = 20,
    int otherOffset = 0,
    int scheduledOffset = 0,
    required TransactionFilter filter,
  }) async {
    scopes.add(List<String>.unmodifiable(accountIds));
    final held = gate;
    if (held != null) await held.future;
    return SortedTransactionsList.empty;
  }
}

class _FakeAccountsService extends Fake implements AccountsService {}

class _TestAccountsNotifier extends AccountsNotifier {
  _TestAccountsNotifier(List<Account> initial) : super(_FakeAccountsService(), initialAccounts: initial);

  void setAccounts(List<Account> accounts) => state = AsyncValue.data(accounts);
}

void main() {
  late _FakeHistoryService history;
  late ProviderContainer container;

  setUp(() {
    history = _FakeHistoryService();
    container = ProviderContainer(
      overrides: [chainHistoryServiceProvider.overrideWithValue(history), isOnlineProvider.overrideWithValue(true)],
    );
  });

  tearDown(() => container.dispose());

  /// Constructing the controller starts the first-page load, the same way
  /// `_init` does in the app.
  UnifiedPaginationController controller() {
    final provider = StateNotifierProvider<UnifiedPaginationController, PaginationState>(
      (ref) => UnifiedPaginationController(ref, accountIds: const ['qz-account']),
    );
    return container.read(provider.notifier);
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

  test('overlapping refreshes hit the indexer once', () async {
    history.gate = Completer<void>();

    final c = controller();
    await settle();
    expect(history.calls, 1, reason: 'construction starts exactly one load');

    final joined = Future.wait([c.loadingRefresh(), c.silentRefresh(), c.loadingRefresh()]);
    await settle();
    expect(history.calls, 1, reason: 'concurrent callers must join the in-flight load');

    history.gate!.complete();
    await joined;
    expect(history.calls, 1, reason: 'joining callers must not re-fetch once it resolves');
  });

  test('a refresh after the in-flight load finishes does fetch again', () async {
    final c = controller();
    await settle();
    expect(history.calls, 1);

    await c.loadingRefresh();
    expect(history.calls, 2, reason: 'the guard must clear once nothing is in flight');
  });

  test('an account switch mid-flight still loads the new scope', () async {
    final oldAccount = makeAccount(1);
    final newAccount = makeAccount(2);
    final accounts = _TestAccountsNotifier([oldAccount]);

    container = ProviderContainer(
      overrides: [
        chainHistoryServiceProvider.overrideWithValue(history),
        isOnlineProvider.overrideWithValue(true),
        accountsProvider.overrideWith((ref) => accounts),
      ],
    );

    // accountIds: null makes the controller follow accountsProvider, which is
    // what the app does and what wires up the listener.
    final provider = StateNotifierProvider<UnifiedPaginationController, PaginationState>(
      (ref) => UnifiedPaginationController(ref),
    );

    history.gate = Completer<void>();
    container.read(provider.notifier);

    // `_init` waits on the provider's stream, which only emits on change — the
    // app sees loading settle into data. Emitting the starting set does that.
    accounts.setAccounts([oldAccount]);
    await settle();
    expect(history.scopes, [
      [oldAccount.accountId],
    ], reason: 'the first load runs for the accounts present at construction');

    // Switch accounts while that first load is still open.
    accounts.setAccounts([newAccount]);
    await settle();
    expect(history.calls, 1, reason: 'the new scope waits rather than piling onto the indexer');

    history.gate!.complete();
    await settle();
    await settle();

    expect(history.scopes, [
      [oldAccount.accountId],
      [newAccount.accountId],
    ], reason: 'a scope change must queue behind the running load, never be dropped');
  });
}
