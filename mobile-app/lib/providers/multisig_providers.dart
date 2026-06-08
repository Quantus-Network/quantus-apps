import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/controllers/multisig_open_proposals_pagination_controller.dart';
import 'package:resonance_network_wallet/providers/multisig_service_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

export 'package:resonance_network_wallet/providers/multisig_service_provider.dart';

class MultisigAccountsNotifier extends StateNotifier<AsyncValue<List<MultisigAccount>>> {
  final SettingsService _settingsService;

  MultisigAccountsNotifier(this._settingsService) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final accounts = await _settingsService.getMultisigAccounts();
      state = AsyncValue.data(accounts);
    } catch (e, st) {
      debugPrint('multisig accounts load error: $e $st');
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(MultisigAccount account) async {
    await _settingsService.addMultisigAccount(account);

    final current = state.value ?? [];
    state = AsyncValue.data([...current, account]);
  }

  Future<void> updateName(MultisigAccount account, String name) async {
    if (name.isEmpty) {
      throw Exception("Multisig name can't be empty");
    }
    final updated = account.copyWith(name: name);
    await _settingsService.updateMultisigAccount(updated);

    final current = state.value ?? [];
    state = AsyncValue.data(current.map((a) => a.accountId == updated.accountId ? updated : a).toList());
  }

  Future<void> remove(String accountId) async {
    await _settingsService.removeMultisigAccount(accountId);

    final current = state.value ?? [];
    state = AsyncValue.data(current.where((a) => a.accountId != accountId).toList());
  }

  MultisigAccount? byAccountId(String accountId) {
    return state.value?.firstWhere(
      (a) => a.accountId == accountId,
      orElse: () => throw Exception('Multisig $accountId not found'),
    );
  }

  void reset() {
    state = const AsyncValue.data([]);
  }
}

final multisigAccountsProvider = StateNotifierProvider<MultisigAccountsNotifier, AsyncValue<List<MultisigAccount>>>((
  ref,
) {
  final settings = ref.watch(settingsServiceProvider);
  return MultisigAccountsNotifier(settings);
});

final discoveredMultisigsProvider = FutureProvider.autoDispose<List<MultisigAccount>>((ref) async {
  final service = ref.watch(multisigServiceProvider);
  final accountsAsync = ref.watch(accountsProvider);

  final List<Account> accounts;
  switch (accountsAsync) {
    case AsyncData(:final value):
      accounts = value;
    case AsyncError(:final error, :final stackTrace):
      Error.throwWithStackTrace(error, stackTrace);
    case AsyncLoading():
      accounts = await ref.read(accountsServiceProvider).getAccounts();
  }

  final ids = accounts.map((a) => a.accountId).toList();
  return service.discoverForUser(ids);
});

/// Past proposals for a multisig activity feed, filtered server-side by status.
final multisigPastProposalsProvider = FutureProvider.autoDispose.family<List<MultisigProposal>, MultisigAccount>((
  ref,
  msig,
) async {
  final service = ref.watch(multisigServiceProvider);
  return service.getPastProposals(msig);
});

/// Invalidates open, past, and block providers after a proposal state change.
void invalidateMultisigProposals(Ref ref, MultisigAccount msig) {
  _invalidateMultisigProposals(ref, msig);
}

/// Widget-layer entry point for [invalidateMultisigProposals].
void invalidateMultisigProposalsFromWidget(WidgetRef ref, MultisigAccount msig) {
  _invalidateMultisigProposals(ref, msig);
}

void _invalidateMultisigProposals(dynamic ref, MultisigAccount msig) {
  ref.invalidate(multisigOpenProposalsPaginationProvider(msig));
  ref.invalidate(multisigPastProposalsProvider(msig));
  ref.invalidate(multisigCurrentBlockProvider);
}

/// Current best block number, used to derive proposal expiry.
final multisigCurrentBlockProvider = FutureProvider.autoDispose<int>((ref) async {
  final service = ref.watch(multisigServiceProvider);
  return service.currentBlockNumber();
});
