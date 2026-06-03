import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

final multisigServiceProvider = Provider<MultisigService>((ref) => MultisigService());

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
    state.whenData((current) {
      state = AsyncValue.data([...current, account]);
    });
  }

  Future<void> updateName(MultisigAccount account, String name) async {
    if (name.isEmpty) {
      throw Exception("Multisig name can't be empty");
    }
    final updated = account.copyWith(name: name);
    await _settingsService.updateMultisigAccount(updated);
    state.whenData((current) {
      state = AsyncValue.data(current.map((a) => a.accountId == updated.accountId ? updated : a).toList());
    });
  }

  Future<void> remove(String accountId) async {
    await _settingsService.removeMultisigAccount(accountId);
    state.whenData((current) {
      state = AsyncValue.data(current.where((a) => a.accountId != accountId).toList());
    });
  }

  MultisigAccount? byAccountId(String accountId) {
    return state.value?.firstWhere(
      (a) => a.accountId == accountId,
      orElse: () => throw Exception('Multisig $accountId not found'),
    );
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
  final accounts = accountsAsync.value ?? [];
  final ids = accounts.map((a) => a.accountId).toList();
  return service.discoverForUser(ids);
});

final multisigLookupProvider = FutureProvider.autoDispose.family<MultisigAccount?, String>((ref, address) async {
  final service = ref.watch(multisigServiceProvider);
  final accountsAsync = ref.watch(accountsProvider);
  final ids = (accountsAsync.value ?? []).map((a) => a.accountId).toList();
  return service.lookupByAddress(address, ids);
});

final multisigOpenProposalsProvider = FutureProvider.autoDispose.family<List<MultisigProposal>, MultisigAccount>((
  ref,
  msig,
) async {
  final service = ref.watch(multisigServiceProvider);
  return service.getOpenProposals(msig);
});

final multisigPastProposalsProvider = FutureProvider.autoDispose.family<List<MultisigProposal>, MultisigAccount>((
  ref,
  msig,
) async {
  final service = ref.watch(multisigServiceProvider);
  return service.getPastProposals(msig);
});

class ProposalKey {
  final MultisigAccount msig;
  final int id;
  const ProposalKey(this.msig, this.id);

  @override
  bool operator ==(Object other) => other is ProposalKey && other.msig.accountId == msig.accountId && other.id == id;

  @override
  int get hashCode => Object.hash(msig.accountId, id);
}

final multisigProposalProvider = FutureProvider.autoDispose.family<MultisigProposal?, ProposalKey>((ref, key) async {
  final service = ref.watch(multisigServiceProvider);
  return service.getProposal(key.msig, key.id);
});
