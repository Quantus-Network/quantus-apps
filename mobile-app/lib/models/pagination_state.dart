// State for pagination
import 'package:quantus_sdk/quantus_sdk.dart';

class PaginationState {
  final List<TransactionEvent> otherTransfers;
  final List<ReversibleTransferEvent> scheduledReversibleTransfers;
  final int scheduledOffset;
  final int otherOffset;
  final bool hasMore;
  final bool isFetching;
  final Object? error;
  final StackTrace? stackTrace;

  PaginationState({
    required this.otherTransfers,
    required this.scheduledReversibleTransfers,
    this.scheduledOffset = 0,
    this.otherOffset = 0,
    required this.hasMore,
    required this.isFetching,
    this.error,
    this.stackTrace,
  });

  factory PaginationState.initial() =>
      PaginationState(otherTransfers: [], scheduledReversibleTransfers: [], hasMore: true, isFetching: false);

  PaginationState copyWith({
    List<TransactionEvent>? otherTransfers,
    List<ReversibleTransferEvent>? scheduledReversibleTransfers,
    int? scheduledOffset,
    int? otherOffset,
    bool? hasMore,
    bool? isFetching,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return PaginationState(
      otherTransfers: otherTransfers ?? this.otherTransfers,
      scheduledReversibleTransfers: scheduledReversibleTransfers ?? this.scheduledReversibleTransfers,
      scheduledOffset: scheduledOffset ?? this.scheduledOffset,
      otherOffset: otherOffset ?? this.otherOffset,
      hasMore: hasMore ?? this.hasMore,
      isFetching: isFetching ?? this.isFetching,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }
}
