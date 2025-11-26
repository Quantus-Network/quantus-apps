import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/notification_config_provider.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends ConsumerState<NotificationsSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final config = ref.watch(notificationConfigProvider);
    final configNotifier = ref.read(notificationConfigProvider.notifier);

    return ScaffoldBase(
      decorations: [
        const Positioned(bottom: 40, left: -80, child: Sphere(variant: 4, size: 251.62)),
        const Positioned(top: -10, right: -30, child: Sphere(variant: 3, size: 194)),
      ],
      appBar: WalletAppBar(title: 'Notifications Settings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 12, bottom: 12, left: 12, right: 26),
            decoration: ShapeDecoration(
              color: context.themeColors.buttonGlass,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/notification/notification_settings_icon.png', width: 21, height: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Notifications', style: context.themeText.largeTag),
                      const SizedBox(height: 4),
                      Text(
                        config.enabled ? 'ON' : 'OFF',
                        style: context.themeText.detail?.copyWith(color: context.themeColors.textMuted),
                      ),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: config.enabled,
                  onChanged: (newValue) {
                    configNotifier.updateConfig(config.copyWith(enabled: newValue));
                  },
                  activeTrackColor: context.themeColors.buttonSuccess,
                  inactiveTrackColor: context.themeColors.textMuted,
                  thumbColor: context.themeColors.buttonNeutral,
                ),
              ],
            ),
          ),
          if (config.enabled) ...[
            const SizedBox(height: 25),
            _buildNotificationToggle(
              context,
              label: 'Sent Tokens',
              value: config.sentTokensEnabled,
              onChanged: (newValue) {
                configNotifier.updateConfig(config.copyWith(sentTokensEnabled: newValue));
              },
            ),
            const SizedBox(height: 12),
            _buildNotificationToggle(
              context,
              label: 'Received Tokens',
              value: config.receivedTokensEnabled,
              onChanged: (newValue) {
                configNotifier.updateConfig(config.copyWith(receivedTokensEnabled: newValue));
              },
            ),
            const SizedBox(height: 12),
            _buildNotificationToggle(
              context,
              label: 'Recovery Timer Ending',
              value: config.recoveryTimerEndingEnabled,
              onChanged: (newValue) {
                configNotifier.updateConfig(config.copyWith(recoveryTimerEndingEnabled: newValue));
              },
            ),
          ],
        ],
      ),
    );
  }

  Container _buildNotificationToggle(
    BuildContext context, {
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 13, bottom: 13, left: 18, right: 26),
      decoration: ShapeDecoration(
        color: context.themeColors.buttonGlass,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.themeText.smallParagraph),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: context.themeColors.buttonSuccess,
            inactiveTrackColor: context.themeColors.textMuted,
            thumbColor: context.themeColors.buttonNeutral,
          ),
        ],
      ),
    );
  }
}
