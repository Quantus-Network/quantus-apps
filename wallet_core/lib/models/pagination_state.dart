// State for pagination
import 'package:quantus_sdk/quantus_sdk.dart';

class PaginationState {
  final List<TransactionEvent> otherTransfers;
  final List<ReversibleTransferEvent> scheduledReversibleTransfers;

  /// Keyset the next scheduled-reversible page continues from; null until the
  /// first page has loaded.
  final AccountEventCursor? scheduledCursor;

  /// Keyset the next other-transfers page continues from; null until the first
  /// page has loaded.
  final AccountEventCursor? otherCursor;
  final bool hasMore;
  final bool isFetching;
  final bool isLoading;
  final Object? error;
  final StackTrace? stackTrace;

  bool get hasLoadedChainData => otherTransfers.isNotEmpty || scheduledReversibleTransfers.isNotEmpty;

  PaginationState({
    required this.otherTransfers,
    required this.scheduledReversibleTransfers,
    this.scheduledCursor,
    this.otherCursor,
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
  /// Cursors are always taken from the arguments (a page that returned no rows
  /// legitimately hands back null), so pass both whenever a page has loaded.
  ///
  /// For [error] and [stackTrace]: omitted arguments keep the current values.
  /// Pass [error] and/or [stackTrace] to set them. Pass [clearError] true to
  /// set both to null; [clearError] takes precedence over [error] and
  /// [stackTrace] when all are provided.
  PaginationState copyWith({
    List<TransactionEvent>? otherTransfers,
    List<ReversibleTransferEvent>? scheduledReversibleTransfers,
    ({AccountEventCursor? scheduled, AccountEventCursor? other})? cursors,
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
      scheduledCursor: cursors == null ? scheduledCursor : cursors.scheduled,
      otherCursor: cursors == null ? otherCursor : cursors.other,
      hasMore: hasMore ?? this.hasMore,
      isFetching: isFetching ?? this.isFetching,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      stackTrace: clearError ? null : (stackTrace ?? this.stackTrace),
    );
  }
}
