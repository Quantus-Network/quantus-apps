import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/multisig_past_proposals_pagination_state.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_service_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class MultisigPastProposalsPaginationController extends StateNotifier<MultisigPastProposalsPaginationState> {
  MultisigPastProposalsPaginationController(this.ref, this.msig, {int pageLimit = 20})
    : _limit = pageLimit,
      super(MultisigPastProposalsPaginationState.initial()) {
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
          .fetchPastProposalsPage(msig, limit: _limit, offset: state.offset);

      state = state.copyWith(
        proposals: [...state.proposals, ...page.items],
        offset: state.offset + page.items.length,
        hasMore: page.hasMore,
        isFetching: false,
        isLoading: false,
        clearError: true,
      );
    } catch (e, st) {
      quantusDebugPrint('Past proposals fetch failed: $e\n$st');
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
      final page = await ref.read(multisigServiceProvider).fetchPastProposalsPage(msig, limit: _limit, offset: 0);
      state = state.copyWith(
        proposals: page.items,
        offset: page.items.length,
        hasMore: page.hasMore,
        clearError: true,
      );
    } catch (e, st) {
      quantusDebugPrint('Past proposals silent refresh failed: $e\n$st');
    } finally {
      state = state.copyWith(isFetching: false, isLoading: false);
    }
  }

  Future<void> loadingRefresh() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) return;

    state = MultisigPastProposalsPaginationState.initial();
    await _fetchPage();
  }
}

final multisigPastProposalsPaginationProvider = StateNotifierProvider.autoDispose
    .family<MultisigPastProposalsPaginationController, MultisigPastProposalsPaginationState, MultisigAccount>(
      (ref, msig) => MultisigPastProposalsPaginationController(ref, msig),
    );
