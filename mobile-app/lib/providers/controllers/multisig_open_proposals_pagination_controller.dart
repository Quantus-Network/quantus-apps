import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/multisig_open_proposals_pagination_state.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class MultisigOpenProposalsPaginationController extends StateNotifier<MultisigOpenProposalsPaginationState> {
  MultisigOpenProposalsPaginationController(this.ref, this.msig, {int pageLimit = 20})
    : _limit = pageLimit,
      super(MultisigOpenProposalsPaginationState.initial()) {
    _init();
  }

  final Ref ref;
  final MultisigAccount msig;
  final int _limit;

  Future<void> _init() async {
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    try {
      state = state.copyWith(isFetching: true, isLoading: true, clearError: true);
      final page = await ref
          .read(multisigServiceProvider)
          .fetchOpenProposalsPage(msig, limit: _limit, offset: state.offset);

      state = state.copyWith(
        proposals: [...state.proposals, ...page.items],
        offset: state.offset + page.items.length,
        hasMore: page.hasMore,
        isFetching: false,
        isLoading: false,
        clearError: true,
      );
    } catch (e, st) {
      quantusDebugPrint('Open proposals fetch failed: $e\n$st');
      state = state.copyWith(error: e, stackTrace: st, isFetching: false, isLoading: false);
    }
  }

  Future<void> fetchMore() async {
    if (state.isFetching || !state.hasMore) return;
    await _fetchPage();
  }

  Future<void> silentRefresh() async {
    if (state.isFetching) return;

    state = state.copyWith(isFetching: true);
    try {
      final page = await ref.read(multisigServiceProvider).fetchOpenProposalsPage(msig, limit: _limit, offset: 0);
      state = state.copyWith(proposals: page.items, offset: page.items.length, hasMore: page.hasMore, clearError: true);
    } catch (e, st) {
      quantusDebugPrint('Open proposals silent refresh failed: $e\n$st');
    } finally {
      state = state.copyWith(isFetching: false, isLoading: false);
    }
  }

  Future<void> loadingRefresh() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) return;

    state = MultisigOpenProposalsPaginationState.initial();
    await _fetchPage();
  }
}

final multisigOpenProposalsPaginationProvider = StateNotifierProvider.autoDispose
    .family<MultisigOpenProposalsPaginationController, MultisigOpenProposalsPaginationState, MultisigAccount>(
      (ref, msig) => MultisigOpenProposalsPaginationController(ref, msig),
    );
