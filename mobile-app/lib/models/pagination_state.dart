// State for pagination
import 'package:quantus_sdk/quantus_sdk.dart';

class PaginationState {
  final List<TransactionEvent> otherTransfers;
  final List<ReversibleTransferEvent> scheduledReversibleTransfers;
  final int scheduledOffset;
  final int otherOffset;
  final bool hasMore;
  final bool isFetching;
  final bool isLoading;
  final Object? error;
  final StackTrace? stackTrace;

  bool get hasLoadedChainData => otherTransfers.isNotEmpty || scheduledReversibleTransfers.isNotEmpty;

  PaginationState({
    required this.otherTransfers,
    required this.scheduledReversibleTransfers,
    this.scheduledOffset = 0,
    this.otherOffset = 0,
    required this.hasMore,
    required this.isFetching,
    required this.isLoading,
    this.error,
    this.stackTrace,
  });

  factory PaginationState.initial() => PaginationState(
    otherTransfers: [],
    scheduledReversibleTransfers: [],
    hasMore: true,
    isFetching: false,
    isLoading: true,
  );

  /// Returns a copy with the given fields replaced.
  ///
  /// For [error] and [stackTrace]: omitted arguments keep the current values.
  /// Pass [error] and/or [stackTrace] to set them. Pass [clearError] true to
  /// set both to null; [clearError] takes precedence over [error] and
  /// [stackTrace] when all are provided.
  PaginationState copyWith({
    List<TransactionEvent>? otherTransfers,
    List<ReversibleTransferEvent>? scheduledReversibleTransfers,
    int? scheduledOffset,
    int? otherOffset,
    bool? hasMore,
    bool? isFetching,
    bool? isLoading,
    Object? error,
    StackTrace? stackTrace,
    bool clearError = false,
  }) {
    return PaginationState(
      otherTransfers: otherTransfers ?? this.otherTransfers,
      scheduledReversibleTransfers: scheduledReversibleTransfers ?? this.scheduledReversibleTransfers,
      scheduledOffset: scheduledOffset ?? this.scheduledOffset,
      otherOffset: otherOffset ?? this.otherOffset,
      hasMore: hasMore ?? this.hasMore,
      isFetching: isFetching ?? this.isFetching,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      stackTrace: clearError ? null : (stackTrace ?? this.stackTrace),
    );
  }
}
