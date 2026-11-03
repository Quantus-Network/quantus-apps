import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/active_swap_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/local_notifications_service.dart';
import 'package:resonance_network_wallet/services/swap_live_activity.dart';
import 'package:resonance_network_wallet/services/swap_live_activity_client.dart';
import 'package:resonance_network_wallet/services/swap_live_activity_push.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// The inputs [decideSwapLiveActivity] needs, read at the moment of a sync.
class SwapLiveSnapshot {
  final ActiveSwap? swap;
  final AppLocalizations l10n;
  final String Function(BigInt amount, SwapToken token) formatAmount;
  final DateTime now;
  final bool progressVisible;

  const SwapLiveSnapshot({
    required this.swap,
    required this.l10n,
    required this.formatAmount,
    required this.now,
    required this.progressVisible,
  });
}

/// Keeps the lock-screen card in step with the swap being followed. A refresh
/// that does not change the card is skipped until [swapLiveRefreshAfter], so
/// the stale deadline keeps moving without a push on every poll.
///
/// On iOS, a Live Activity is used only when the OS can run one and the user
/// has allowed it. Otherwise the same updates go to a normal notification.
class SwapLiveActivityController {
  final SwapLiveActivityClient _client;
  final SwapLiveActivityRegistrar _push;
  final SwapLiveSnapshot Function() _snapshot;
  final Future<String?> Function()? _deviceToken;
  final String? _devicePushPlatform;
  final bool Function() _isIOS;
  final SwapLiveNotificationPoster? _notifications;

  final Set<String> _dismissed = {};
  StreamSubscription<SwapLiveActivityEvent>? _events;
  Future<void> _tail = Future<void>.value();

  bool _foreground = true;
  bool _unsupported = false;
  bool _shown = false;
  bool _notification = false;
  bool _activityShown = false;
  bool _cleared = false;
  String? _shownKey;
  Map<String, Object?>? _identity;
  DateTime? _deliveredAt;
  String? _activityToken;
  String? _registeredToken;
  SwapLiveActivityContent? _shownContent;

  SwapLiveActivityController({
    required SwapLiveActivityClient client,
    required SwapLiveActivityRegistrar push,
    required SwapLiveSnapshot Function() snapshot,
    Future<String?> Function()? deviceToken,
    String? devicePushPlatform,
    bool foreground = true,
    bool Function()? isIOS,
    SwapLiveNotificationPoster? notifications,
  }) : _client = client,
       _push = push,
       _snapshot = snapshot,
       _deviceToken = deviceToken,
       _devicePushPlatform = devicePushPlatform,
       _foreground = foreground,
       _isIOS = isIOS ?? (() => Platform.isIOS),
       _notifications = notifications {
    _events = _client.events.listen(_onEvent);
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    sync();
  }

  Future<void> sync() {
    final run = _tail.then((_) => _sync());
    _tail = run.catchError((Object e) => quantusPrint('Swap live activity sync failed: $e'));
    return run;
  }

  Future<void> _sync() async {
    if (_unsupported) return;
    final snap = _snapshot();
    final decision = decideSwapLiveActivity(
      swap: snap.swap,
      l10n: snap.l10n,
      formatAmount: snap.formatAmount,
      now: snap.now,
      progressVisible: snap.progressVisible,
      appInForeground: _foreground,
    );
    final content = decision.content;
    if (decision.command == SwapLiveCommand.end || content == null) {
      await _end();
      return;
    }
    if (_dismissed.contains(content.key)) {
      await _end();
      return;
    }
    if (_shown && _shownKey == content.key && _unchanged(content, snap.now)) return;
    final changed = !mapEquals(_identity, content.identity);
    final presented = await _present(content);
    if (!presented) return;
    _shown = true;
    _shownKey = content.key;
    _identity = content.identity;
    _deliveredAt = snap.now;
    _shownContent = content;
    if (changed || _registeredToken == null) await _register(content);
  }

  Future<bool> _useNotification() async {
    if (!_isIOS()) return false;
    try {
      final capabilities = await _client.capabilities();
      return selectSwapLivePresentation(capabilities) == SwapLivePresentation.notification;
    } on MissingPluginException {
      return true;
    }
  }

  /// Shows the activity or the fallback notification. Returns false when the
  /// native card is missing on a platform that has no notification fallback,
  /// which stops further attempts.
  Future<bool> _present(SwapLiveActivityContent content) async {
    if (await _useNotification()) {
      await _presentNotification(content);
      return true;
    }
    try {
      await _client.show(content.toPayload());
    } on MissingPluginException {
      if (!_isIOS()) {
        _unsupported = true;
        return false;
      }
      await _presentNotification(content);
      return true;
    } on PlatformException catch (error) {
      if (error.code != 'activities_unavailable') rethrow;
      await _presentNotification(content);
      return true;
    }
    _activityShown = true;
    if (_notification) {
      await _notifications?.cancel();
      _notification = false;
    }
    return true;
  }

  Future<void> _presentNotification(SwapLiveActivityContent content) async {
    final poster = _notifications;
    if (poster == null) {
      throw StateError('Swap notification poster is not configured');
    }
    if (_activityShown) {
      _notification = true;
      _activityShown = false;
      _activityToken = null;
      final token = _registeredToken;
      _registeredToken = null;
      try {
        await _client.endQuietly();
      } on MissingPluginException {
        quantusPrint('Swap live activity end had no native handler');
      }
      if (token != null) {
        try {
          await _push.unregister(token);
        } catch (error) {
          quantusPrint('Swap live activity unregister failed: $error');
        }
      }
    }
    await poster.show(content);
    _notification = true;
  }

  bool _unchanged(SwapLiveActivityContent content, DateTime now) {
    if (!mapEquals(_identity, content.identity)) return false;
    final delivered = _deliveredAt;
    return delivered != null && now.difference(delivered) < swapLiveRefreshAfter;
  }

  Future<void> _register(SwapLiveActivityContent content) async {
    if (content.simulated) return;
    final activity = _activityToken;
    if (activity != null) await _registerToken(activity, 'ios', content);
    final platform = _devicePushPlatform;
    final deviceToken = _deviceToken;
    if (platform == null || deviceToken == null) return;
    final token = await deviceToken();
    if (token == null) return;
    await _registerToken(token, platform, content);
  }

  Future<void> _registerToken(String token, String platform, SwapLiveActivityContent content) async {
    try {
      await _push.register(token: token, platform: platform, content: content);
      _registeredToken = token;
    } catch (e) {
      quantusPrint('Swap live activity registration failed: $e');
    }
  }

  Future<void> _end() async {
    if (!_shown && _registeredToken == null && _cleared && !_notification) return;
    if (_notification) {
      await _notifications?.cancel();
      _notification = false;
    }
    _activityShown = false;
    _cleared = true;
    final token = _registeredToken;
    _shown = false;
    _shownKey = null;
    _identity = null;
    _deliveredAt = null;
    _shownContent = null;
    _registeredToken = null;
    await _client.end();
    if (token == null) return;
    try {
      await _push.unregister(token);
    } catch (e) {
      quantusPrint('Swap live activity unregister failed: $e');
    }
  }

  void _onEvent(SwapLiveActivityEvent event) {
    switch (event) {
      case SwapLiveDismissed():
        if (_notification) return;
        final key = _shownKey;
        if (key != null) _dismissed.add(key);
        sync();
      case SwapLiveToken(:final token):
        if (_notification) return;
        _activityToken = token;
        final content = _shownContent;
        if (content != null) unawaited(_registerToken(token, 'ios', content));
    }
  }

  Future<void> dispose() async {
    await _events?.cancel();
  }
}

/// Whether the swap progress screen is the route on screen. The finished card
/// stays up only while that is true.
final swapProgressVisibleProvider = NotifierProvider<SwapProgressVisible, bool>(SwapProgressVisible.new);

class SwapProgressVisible extends Notifier<bool> {
  @override
  bool build() => false;

  /// Records [visible]. A write that lands after the app has gone away is dropped:
  /// the provider, and anything listening to it, is already gone.
  void set(bool visible) {
    if (!ref.mounted) return;
    state = visible;
  }
}

final swapLiveActivityClientProvider = Provider<SwapLiveActivityClient>((ref) {
  final client = MethodChannelSwapLiveActivity();
  ref.onDispose(client.dispose);
  return client;
});

final swapLiveActivityPushProvider = Provider<SwapLiveActivityPush>((ref) => SwapLiveActivityPush());

final swapLiveActivityControllerProvider = Provider<SwapLiveActivityController>((ref) {
  final controller = SwapLiveActivityController(
    client: ref.watch(swapLiveActivityClientProvider),
    push: ref.watch(swapLiveActivityPushProvider),
    deviceToken: () => ref.read(firebaseMessagingServiceProvider).getDeviceToken(),
    devicePushPlatform: Platform.isAndroid ? 'android' : null,
    notifications: LocalSwapLiveNotificationPoster(ref.read(localNotificationsServiceProvider)),
    snapshot: () {
      final formatting = ref.read(numberFormattingServiceProvider);
      return SwapLiveSnapshot(
        swap: ref.read(activeSwapProvider),
        l10n: ref.read(l10nProvider),
        formatAmount: (amount, token) => formatting.formatAmount(amount, decimals: token.decimals),
        now: clock.now(),
        progressVisible: ref.read(swapProgressVisibleProvider),
      );
    },
  );
  final observer = _SwapLiveActivityLifecycle(controller);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    controller.dispose();
  });
  ref.listen(activeSwapProvider, (_, _) => controller.sync());
  ref.listen(swapProgressVisibleProvider, (_, _) => controller.sync());
  ref.listen(l10nProvider, (_, _) => controller.sync());
  final lifecycle = WidgetsBinding.instance.lifecycleState;
  controller.setForeground(lifecycle == null || lifecycle == AppLifecycleState.resumed);
  controller.sync();
  return controller;
});

class _SwapLiveActivityLifecycle extends WidgetsBindingObserver {
  final SwapLiveActivityController controller;

  _SwapLiveActivityLifecycle(this.controller);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    controller.setForeground(state == AppLifecycleState.resumed);
  }
}
