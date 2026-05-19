import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class OptInPositionNotifier extends StateNotifier<AsyncValue<OptedInPosition>> {
  final TaskmasterService _taskmasterService = TaskmasterService();

  OptInPositionNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      final optInPosition = await _taskmasterService.getOptInPosition();

      state = AsyncValue.data(optInPosition);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}

final optInPositionProvider = StateNotifierProvider<OptInPositionNotifier, AsyncValue<OptedInPosition>>((ref) {
  return OptInPositionNotifier();
});
