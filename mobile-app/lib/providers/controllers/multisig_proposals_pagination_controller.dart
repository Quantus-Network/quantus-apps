import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/multisig_proposals_pagination_state.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_service_provider.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

typedef FetchMultisigProposalsPage =
    Future<MultisigProposalsPage> Function(
      MultisigService service,
      MultisigAccount msig, {
      required int limit,
      required int offset,
    });

class MultisigProposalsPaginationController extends StateNotifier<MultisigProposalsPaginationState> {
  MultisigProposalsPaginationController(
    this.ref,
    this.msig,
    this._fetchPage, {
    required this.logLabel,
    int pageLimit = 20,
  }) : _limit = pageLimit,
       super(MultisigProposalsPaginationState.initial()) {
    _init();
  }

  final Ref ref;
  final MultisigAccount msig;
  final FetchMultisigProposalsPage _fetchPage;
  final String logLabel;
  final int _limit;

  Future<void> _init() async {
    await _fetchPageInternal();
  }

  Future<void> _fetchPageInternal() async {
    try {
      state = state.copyWith(isFetching: true, isLoading: true, clearError: true);
      final page = await _fetchPage(
        ref.read(multisigServiceProvider),
        msig,
        limit: _limit,
        offset: state.offset,
      );

      state = state.copyWith(
        proposals: [...state.proposals, ...page.items],
        offset: state.offset + page.items.length,
        hasMore: page.hasMore,
        isFetching: false,
        isLoading: false,
        clearError: true,
      );
    } catch (e, st) {
      quantusDebugPrint('$logLabel fetch failed: $e\n$st');
      state = state.copyWith(error: e, stackTrace: st, isFetching: false, isLoading: false);
    }
  }

  Future<void> fetchMore() async {
    if (state.isFetching || !state.hasMore) return;
    await _fetchPageInternal();
  }

  Future<void> silentRefresh() async {
    if (state.isFetching) return;

    state = state.copyWith(isFetching: true);
    try {
      final page = await _fetchPage(
        ref.read(multisigServiceProvider),
        msig,
        limit: _limit,
        offset: 0,
      );
      state = state.copyWith(
        proposals: page.items,
        offset: page.items.length,
        hasMore: page.hasMore,
        clearError: true,
      );
    } catch (e, st) {
      quantusDebugPrint('$logLabel silent refresh failed: $e\n$st');
    } finally {
      state = state.copyWith(isFetching: false, isLoading: false);
    }
  }

  Future<void> loadingRefresh() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) return;

    state = MultisigProposalsPaginationState.initial();
    await _fetchPageInternal();
  }
}

Future<MultisigProposalsPage> _fetchOpenProposalsPage(
  MultisigService service,
  MultisigAccount msig, {
  required int limit,
  required int offset,
}) {
  return service.fetchOpenProposalsPage(msig, limit: limit, offset: offset);
}

Future<MultisigProposalsPage> _fetchPastProposalsPage(
  MultisigService service,
  MultisigAccount msig, {
  required int limit,
  required int offset,
}) {
  return service.fetchPastProposalsPage(msig, limit: limit, offset: offset);
}

final multisigOpenProposalsPaginationProvider = StateNotifierProvider.autoDispose
    .family<MultisigProposalsPaginationController, MultisigProposalsPaginationState, MultisigAccount>(
      (ref, msig) => MultisigProposalsPaginationController(
        ref,
        msig,
        _fetchOpenProposalsPage,
        logLabel: 'Open proposals',
      ),
    );

final multisigPastProposalsPaginationProvider = StateNotifierProvider.autoDispose
    .family<MultisigProposalsPaginationController, MultisigProposalsPaginationState, MultisigAccount>(
      (ref, msig) => MultisigProposalsPaginationController(
        ref,
        msig,
        _fetchPastProposalsPage,
        logLabel: 'Past proposals',
      ),
    );
