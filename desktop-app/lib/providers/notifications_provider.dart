import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/models/notification_status.dart';
import 'package:quantus_desktop_wallet/models/wallet_presence.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/telemetry.dart';

/// The desktop's system notifications: wallet_core's [LocalNotifications],
/// and what the system lets the app do with them.
///
/// Notifications that cannot be shown never stop the app: the status says
/// why, for Settings to tell the person.
class DesktopLocalNotifications extends Notifier<NotificationStatus> implements LocalNotifications {
  /// Who the app is to Windows, which files its notifications under them.
  static const windowsAppUserModelId = 'Quantus.DesktopWallet';

  /// The app's notification activator on Windows. It must never change: the
  /// system keeps it registered for the app.
  static const windowsActivatorGuid = '745d2a45-cfdc-4f29-91c2-0c8a985a2e19';

  Future<void>? _started;

  @override
  NotificationStatus build() => const NotificationsStarting();

  /// Starts the system's notifications. Started once, however often called.
  Future<void> start() => _started ??= _start();

  Future<void> _start() async {
    final settings = InitializationSettings(
      macOS: const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
      windows: const WindowsInitializationSettings(
        appName: appTitle,
        appUserModelId: windowsAppUserModelId,
        guid: windowsActivatorGuid,
      ),
      linux: LinuxInitializationSettings(defaultActionName: ref.read(l10nProvider).desktopNotificationOpenAction),
    );
    try {
      await ref.read(notificationPluginProvider).initialize(settings, onClick: _open);
    } catch (e) {
      _unavailable(e);
      return;
    }
    state = defaultTargetPlatform == TargetPlatform.macOS
        ? const NotificationsNotAsked()
        : const NotificationsAllowed();
    await _openLaunchClick();
  }

  /// Opens what the click that launched the app was about, if one did: such
  /// a click comes before the notifications were started, so not through
  /// [_open] as a click on the running app does.
  Future<void> _openLaunchClick() async {
    final String? payload;
    try {
      payload = await ref.read(notificationPluginProvider).launchPayload();
    } catch (e) {
      quantusPrint('The click that launched the app could not be read: $e');
      ref.read(telemetryProvider).sendError('desktop_notification_launch_unreadable', error: e);
      return;
    }
    if (payload != null) _open(payload);
  }

  /// Asks macOS whether the app may show notifications. Windows and Linux do
  /// not ask, and nothing can be asked of notifications that are unavailable.
  Future<void> requestPermission() async {
    await start();
    if (defaultTargetPlatform != TargetPlatform.macOS || state is NotificationsUnavailable) return;
    try {
      final allowed = await ref.read(notificationPluginProvider).requestMacOSPermission();
      state = allowed ? const NotificationsAllowed() : const NotificationsDenied();
    } catch (e) {
      _unavailable(e);
    }
  }

  /// Reads again what macOS allows, without asking the person: it may have
  /// been changed in System Settings. Only once the person has answered: the
  /// first prompt takes the focus from the app, and before they answer macOS
  /// would read as not allowing.
  Future<void> recheckPermission() async {
    if (defaultTargetPlatform != TargetPlatform.macOS || !_hasAnswer) return;
    final bool allowed;
    try {
      allowed = await ref.read(notificationPluginProvider).isMacOSPermissionGranted();
    } catch (e) {
      quantusPrint('Reading the notification permission failed: $e');
      if (ref.mounted) ref.read(telemetryProvider).sendError('desktop_notifications_recheck_failed', error: e);
      return;
    }
    if (!ref.mounted || !_hasAnswer) return;
    state = allowed ? const NotificationsAllowed() : const NotificationsDenied();
  }

  bool get _hasAnswer => state is NotificationsAllowed || state is NotificationsDenied;

  /// The account a click asked for, until the wallet's accounts and its
  /// active account have loaded, as at launch.
  String? _clickedAccountId;
  final _untilLoaded = <ProviderSubscription<Object?>>[];

  /// Opens what a clicked notification was about: the window comes to the
  /// front, on the account the notification named when it is still there.
  void _open(String? payload) {
    unawaited(const WindowChrome().bringToFront());
    final String accountId;
    try {
      accountId = (jsonDecode(payload!) as Map<String, dynamic>)['accountId'] as String;
    } catch (e) {
      quantusPrint('A clicked notification could not be read: $e');
      ref.read(telemetryProvider).sendError('desktop_notification_click_unreadable', error: e);
      return;
    }
    _clickedAccountId = accountId;
    if (_openClickedAccount() || _untilLoaded.isNotEmpty) return;
    _untilLoaded
      ..add(ref.listen(sidebarAccountsProvider, (_, _) => _openClickedAccount()))
      ..add(ref.listen(activeAccountProvider, (_, _) => _openClickedAccount()));
  }

  /// Selects the clicked account once the accounts and the active account
  /// have loaded: before that, restoring the saved active account would undo
  /// it. Returns whether the click is done with.
  bool _openClickedAccount() {
    final accountId = _clickedAccountId;
    if (accountId == null) return true;
    final accounts = ref.read(sidebarAccountsProvider);
    if (accounts.isEmpty || !ref.read(activeAccountProvider).hasValue) return false;
    _clickedAccountId = null;
    for (final subscription in _untilLoaded) {
      subscription.close();
    }
    _untilLoaded.clear();
    final account = accounts.where((display) => display.account.accountId == accountId).firstOrNull;
    if (account != null) unawaited(ref.read(sidebarSelectionProvider.notifier).showAccount(account));
    return true;
  }

  void _unavailable(Object error) {
    quantusPrint('Desktop notifications are unavailable: $error');
    ref.read(telemetryProvider).sendError('desktop_notifications_unavailable', error: error);
    state = NotificationsUnavailable(error is StateError ? error.message : '$error');
  }

  /// Shows [notification] now. Callers check [state] first: showing one the
  /// system does not allow fails.
  @override
  Future<void> showOrScheduleNotification(NotificationData notification) async {
    if (notification.hasValidScheduleTime) {
      throw UnsupportedError('Desktop notifications cannot be scheduled: no desktop feature schedules one yet');
    }
    final status = state;
    if (status is! NotificationsAllowed) {
      throw StateError('Desktop notifications are not allowed: ${status.runtimeType}');
    }
    await ref
        .read(notificationPluginProvider)
        .show(
          // The plugins take a 32-bit id.
          id: notification.id.hashCode & 0x7fffffff,
          title: notification.title,
          body: notification.message,
          payload: jsonEncode({'accountId': notification.accountId}),
        );
  }
}

final desktopLocalNotificationsProvider = NotifierProvider<DesktopLocalNotifications, NotificationStatus>(
  DesktopLocalNotifications.new,
);

/// Starts the system's notifications with the app, asks for permission once
/// there is a wallet to notify about, and reads it again whenever the window
/// comes back.
final notificationsStartupProvider = Provider<void>((ref) {
  final notifications = ref.watch(desktopLocalNotificationsProvider.notifier);
  unawaited(notifications.start());
  ref.listen(walletPresenceProvider, (_, presence) {
    if (presence.value == WalletPresence.present) unawaited(notifications.requestPermission());
  }, fireImmediately: true);
  final window = AppLifecycleListener(onResume: () => unawaited(notifications.recheckPermission()));
  ref.onDispose(window.dispose);
});
