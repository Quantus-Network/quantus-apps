import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this platform can keep the app running with its window closed.
bool get supportsBackgroundMode => defaultTargetPlatform == TargetPlatform.macOS;

/// Whether the window is closed with the app still running.
final windowClosedProvider = NotifierProvider<WindowClosedNotifier, bool>(WindowClosedNotifier.new);

class WindowClosedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool isClosed) => state = isClosed;
}

/// Whether the person, having asked to quit with work under way, is being
/// asked what to do about it.
final quitQuestionProvider = NotifierProvider<QuitQuestionNotifier, bool>(QuitQuestionNotifier.new);

class QuitQuestionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool isAsking) => state = isAsking;
}

/// Who has work under way that no pending record shows, such as a send being
/// approved, signed or proved.
final workHoldsProvider = NotifierProvider<WorkHoldsNotifier, Set<Object>>(WorkHoldsNotifier.new);

class WorkHoldsNotifier extends Notifier<Set<Object>> {
  @override
  Set<Object> build() => const {};

  void hold(Object holder) => state = {...state, holder};

  void release(Object holder) {
    if (!ref.mounted || !state.contains(holder)) return;
    state = {...state}..remove(holder);
  }
}
