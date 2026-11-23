import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/notification_status.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_switch.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';

/// The Notifications row of Settings: a switch, or, when the system is the
/// one saying no, why, and on macOS the way to change it.
class NotificationsRow extends ConsumerStatefulWidget {
  const NotificationsRow({super.key});

  static const switchKey = Key('settings-notifications-switch');
  static const openSystemSettingsKey = Key('settings-notifications-open-system-settings');

  /// The Notifications pane of System Settings, on this app.
  static final systemSettingsUrl = Uri.parse(
    'x-apple.systempreferences:com.apple.preference.notifications?id=com.quantus.desktop-wallet',
  );

  @override
  ConsumerState<NotificationsRow> createState() => _NotificationsRowState();
}

class _NotificationsRowState extends ConsumerState<NotificationsRow> {
  /// Whether the last try to open System Settings failed.
  bool _couldNotOpen = false;

  Future<void> _openSystemSettings() async {
    setState(() => _couldNotOpen = false);
    try {
      await ref.read(openExternalUrlProvider)(NotificationsRow.systemSettingsUrl);
    } catch (e) {
      quantusPrint('Opening System Settings failed: $e');
      // The row may be gone by now: the sheet closed, or a step opened.
      if (mounted) setState(() => _couldNotOpen = true);
    }
  }

  void _setEnabled(bool enabled) {
    final config = ref.read(notificationConfigProvider);
    unawaited(ref.read(notificationConfigProvider.notifier).updateConfig(config.copyWith(enabled: enabled)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final title = l10n.settingsPreferencesNotifications;
    ref.listen(desktopLocalNotificationsProvider, (_, _) {
      if (_couldNotOpen) setState(() => _couldNotOpen = false);
    });

    return switch (ref.watch(desktopLocalNotificationsProvider)) {
      NotificationsDenied() => SettingsRow.control(
        title: title,
        subtitle: _couldNotOpen ? l10n.desktopNotificationOpenSystemSettingsFailed : l10n.desktopNotificationNotAllowed,
        isWarning: true,
        trailing: ToolbarActionRow(
          edge: ToolbarActionEdge.trailing,
          children: [
            ToolbarAction.symbol(
              key: NotificationsRow.openSystemSettingsKey,
              symbol: CupertinoIcons.arrow_up_right_square,
              label: l10n.desktopNotificationOpenSystemSettings,
              onPressed: () => unawaited(_openSystemSettings()),
            ),
          ],
        ),
      ),
      NotificationsUnavailable(:final reason) => SettingsRow.control(
        title: title,
        subtitle: l10n.desktopNotificationUnavailable(reason),
        isWarning: true,
        trailing: const SizedBox.shrink(),
      ),
      // Until the system has answered, the person's own choice still holds.
      NotificationsStarting() || NotificationsNotAsked() || NotificationsAllowed() => SettingsRow.control(
        title: title,
        subtitle: l10n.settingsPreferencesNotificationsSubtitle,
        trailing: DesktopSwitch(
          key: NotificationsRow.switchKey,
          value: ref.watch(notificationConfigProvider.select((config) => config.enabled)),
          label: title,
          onChanged: _setEnabled,
        ),
      ),
    };
  }
}
