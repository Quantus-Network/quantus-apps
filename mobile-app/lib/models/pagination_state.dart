// State for pagination
import 'package:quantus_sdk/quantus_sdk.dart';

class PaginationState {
  final List<TransactionEvent> items;
  final List<ReversibleTransferEvent> reversibleTransfers;
  final int transfersOffset;
  final int reversibleOffset;
  final int rewardsOffset;
  final int scheduledOffset;
  final bool hasMore;
  final bool isFetching;
  final Object? error;
  final StackTrace? stackTrace;

  PaginationState({
    required this.items,
    required this.reversibleTransfers,
    this.transfersOffset = 0,
    this.reversibleOffset = 0,
    this.rewardsOffset = 0,
    this.scheduledOffset = 0,
    required this.hasMore,
    required this.isFetching,
    this.error,
    this.stackTrace,
  });

  factory PaginationState.initial() =>
      PaginationState(items: [], reversibleTransfers: [], hasMore: true, isFetching: false);

  PaginationState copyWith({
    List<TransactionEvent>? items,
    List<ReversibleTransferEvent>? reversibleTransfers,
    int? transfersOffset,
    int? reversibleOffset,
    int? rewardsOffset,
    int? scheduledOffset,
    bool? hasMore,
    bool? isFetching,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return PaginationState(
      items: items ?? this.items,
      reversibleTransfers: reversibleTransfers ?? this.reversibleTransfers,
      transfersOffset: transfersOffset ?? this.transfersOffset,
      reversibleOffset: reversibleOffset ?? this.reversibleOffset,
      rewardsOffset: rewardsOffset ?? this.rewardsOffset,
      scheduledOffset: scheduledOffset ?? this.scheduledOffset,
      hasMore: hasMore ?? this.hasMore,
      isFetching: isFetching ?? this.isFetching,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
    );
  }
}
