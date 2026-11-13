import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/legacy.dart';

/// The app's current lifecycle state. The app's lifecycle listener writes it;
/// services read it to pause work while the app is in the background.
final appLifecycleStateProvider = StateProvider<AppLifecycleState>((ref) => AppLifecycleState.resumed);
