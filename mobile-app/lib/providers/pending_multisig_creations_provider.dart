import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class PendingMultisigCreationsNotifier extends StateNotifier<List<PendingMultisigCreationEvent>> {
  PendingMultisigCreationsNotifier() : super([]);

  void add(PendingMultisigCreationEvent event) {
    if (state.any((e) => e.multisigAddress == event.multisigAddress)) return;
    state = [...state, event];
  }

  void remove(String multisigAddress) {
    state = state.where((e) => e.multisigAddress != multisigAddress).toList();
  }

  void clear() {
    state = [];
  }
}

final pendingMultisigCreationsProvider =
    StateNotifierProvider<PendingMultisigCreationsNotifier, List<PendingMultisigCreationEvent>>((ref) {
      return PendingMultisigCreationsNotifier();
    });

void addPendingMultisigCreation(Ref ref, PendingMultisigCreationEvent event) {
  ref.read(pendingMultisigCreationsProvider.notifier).add(event);
}

void removePendingMultisigCreation(Ref ref, String multisigAddress) {
  ref.read(pendingMultisigCreationsProvider.notifier).remove(multisigAddress);
}

void clearPendingMultisigCreations(Ref ref) {
  ref.read(pendingMultisigCreationsProvider.notifier).clear();
}
