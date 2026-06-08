import 'package:quantus_sdk/quantus_sdk.dart';

class MultisigOpenProposalsPaginationState {
  final List<MultisigProposal> proposals;
  final int offset;
  final bool hasMore;
  final bool isFetching;
  final bool isLoading;
  final Object? error;
  final StackTrace? stackTrace;

  bool get hasLoadedData => proposals.isNotEmpty;

  const MultisigOpenProposalsPaginationState({
    required this.proposals,
    this.offset = 0,
    required this.hasMore,
    required this.isFetching,
    required this.isLoading,
    this.error,
    this.stackTrace,
  });

  factory MultisigOpenProposalsPaginationState.initial() {
    return const MultisigOpenProposalsPaginationState(
      proposals: [],
      hasMore: true,
      isFetching: false,
      isLoading: true,
    );
  }

  MultisigOpenProposalsPaginationState copyWith({
    List<MultisigProposal>? proposals,
    int? offset,
    bool? hasMore,
    bool? isFetching,
    bool? isLoading,
    Object? error,
    StackTrace? stackTrace,
    bool clearError = false,
  }) {
    return MultisigOpenProposalsPaginationState(
      proposals: proposals ?? this.proposals,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      isFetching: isFetching ?? this.isFetching,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      stackTrace: clearError ? null : (stackTrace ?? this.stackTrace),
    );
  }
}
