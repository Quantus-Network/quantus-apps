import 'dart:async';

import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// A signal from the native card: the user dismissed it, or iOS issued the
/// push token Senoti needs in order to update the card after the app sleeps.
sealed class SwapLiveActivityEvent {}

class SwapLiveDismissed extends SwapLiveActivityEvent {}

class SwapLiveToken extends SwapLiveActivityEvent {
  final String token;

  SwapLiveToken(this.token);
}

/// The native lock-screen card. [show] replaces whatever is up. [end] removes it.
abstract class SwapLiveActivityClient {
  Future<void> show(Map<String, Object?> payload);

  Future<void> end();

  Stream<SwapLiveActivityEvent> get events;
}

class MethodChannelSwapLiveActivity implements SwapLiveActivityClient {
  static const _methods = MethodChannel('app.quantus/swap_live_activity');
  static const _events = EventChannel('app.quantus/swap_live_activity_events');

  final StreamController<SwapLiveActivityEvent> _controller = StreamController<SwapLiveActivityEvent>.broadcast();
  StreamSubscription<dynamic>? _subscription;

  MethodChannelSwapLiveActivity() {
    _subscription = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object error) => quantusPrint('Swap live activity events unavailable: $error'),
    );
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    switch (event['type']) {
      case 'dismissed':
        _controller.add(SwapLiveDismissed());
      case 'token':
        final token = event['token'];
        if (token is String && token.isNotEmpty) _controller.add(SwapLiveToken(token));
    }
  }

  @override
  Stream<SwapLiveActivityEvent> get events => _controller.stream;

  @override
  Future<void> show(Map<String, Object?> payload) => _methods.invokeMethod<void>('show', payload);

  @override
  Future<void> end() => _methods.invokeMethod<void>('end');

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
