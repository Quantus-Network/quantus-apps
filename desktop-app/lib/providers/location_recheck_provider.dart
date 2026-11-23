import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';

/// Asks again where swaps are allowed each time the window comes back to the
/// front, as the phone does on each return to the app: the computer may have
/// moved since the answer in hand was given, asleep in a bag. The app's start
/// asks by itself, so nothing is asked here until the window has been away.
final locationRecheckProvider = Provider<void>((ref) {
  var wasInFront = _inFront(WidgetsBinding.instance.lifecycleState);
  final window = AppLifecycleListener(
    onStateChange: (state) {
      final isInFront = _inFront(state);
      if (isInFront && !wasInFront) unawaited(ref.read(remoteConfigProvider.notifier).syncConfig());
      wasInFront = isInFront;
    },
  );
  ref.onDispose(window.dispose);
});

/// Whether a window in [state] is the one being used. Before the system has
/// said, it is taken to be.
bool _inFront(AppLifecycleState? state) => state == null || state == AppLifecycleState.resumed;
