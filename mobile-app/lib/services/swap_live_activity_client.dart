import 'dart:async';

import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/services/swap_live_activity.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:swap_live_activity_channel/swap_live_activity_channel.dart';

/// Reads the map returned by the iOS `capabilities` method.
SwapLiveCapabilities parseSwapLiveCapabilities(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('Swap live activity capabilities were not a map');
  }
  final available = raw['available'];
  final authorized = raw['authorized'];
  if (available is! bool || authorized is! bool) {
    throw const FormatException('Swap live activity capabilities were incomplete');
  }
  return SwapLiveCapabilities(available: available, authorized: authorized);
}

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

  /// Ends a Live Activity without the dismissed signal, so a fallback
  /// notification can replace it.
  Future<void> endQuietly() => end();

  /// Live Activity support on this device. Other platforms report that an
  /// activity can run; the caller only asks on iOS.
  Future<SwapLiveCapabilities> capabilities() async => const SwapLiveCapabilities(available: true, authorized: true);

  Stream<SwapLiveActivityEvent> get events;
}

class MethodChannelSwapLiveActivity implements SwapLiveActivityClient {
  static const _methods = MethodChannel(swapLiveActivityChannel);
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

  @override
  Future<void> endQuietly() => _methods.invokeMethod<void>('endQuietly');

  @override
  Future<SwapLiveCapabilities> capabilities() async {
    final raw = await _methods.invokeMethod<Object?>('capabilities');
    return parseSwapLiveCapabilities(raw);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
