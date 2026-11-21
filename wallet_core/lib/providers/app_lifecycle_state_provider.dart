import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The app's current lifecycle state. The app's lifecycle listener writes it;
/// services read it to pause work while the app is in the background.
final appLifecycleStateProvider = StateProvider<AppLifecycleState>((ref) => AppLifecycleState.resumed);

/// Whether the app is on screen. A prompt or the notification shade over it
/// (inactive) still counts; hidden, paused and detached do not.
final appInForegroundProvider = appLifecycleStateProvider.select(
  (state) => state == AppLifecycleState.resumed || state == AppLifecycleState.inactive,
);
