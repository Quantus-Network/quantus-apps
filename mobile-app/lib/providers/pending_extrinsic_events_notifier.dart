import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared list mutations for extrinsics submitted but not yet indexed.
abstract class PendingExtrinsicEventsNotifier<T> extends Notifier<List<T>> {
  @override
  List<T> build() => [];

  String idOf(T event);

  T withExtrinsicHash(T event, String? extrinsicHash);

  void add(T event) {
    state = [...state, event];
  }

  void update(String id, {String? extrinsicHash}) {
    state = [
      for (final event in state)
        if (idOf(event) == id) withExtrinsicHash(event, extrinsicHash) else event,
    ];
  }

  void remove(String id) {
    state = state.where((event) => idOf(event) != id).toList();
  }

  void clear() {
    state = [];
  }
}

T? findPendingExtrinsicEventById<T>(List<T> events, String id, String Function(T event) idOf) {
  for (final event in events) {
    if (idOf(event) == id) return event;
  }
  return null;
}

void addPendingExtrinsicEvent<T>(
  Ref ref,
  NotifierProvider<PendingExtrinsicEventsNotifier<T>, List<T>> provider,
  T event,
) {
  ref.read(provider.notifier).add(event);
}

void updatePendingExtrinsicEvent<T>(
  Ref ref,
  NotifierProvider<PendingExtrinsicEventsNotifier<T>, List<T>> provider,
  String id, {
  String? extrinsicHash,
}) {
  ref.read(provider.notifier).update(id, extrinsicHash: extrinsicHash);
}

void removePendingExtrinsicEvent<T>(
  Ref ref,
  NotifierProvider<PendingExtrinsicEventsNotifier<T>, List<T>> provider,
  String id,
) {
  ref.read(provider.notifier).remove(id);
}
