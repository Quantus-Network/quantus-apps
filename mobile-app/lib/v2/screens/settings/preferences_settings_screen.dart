import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/notification_config_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/currency_picker_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/language_picker_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class PreferencesSettingsScreenV2 extends ConsumerStatefulWidget {
  const PreferencesSettingsScreenV2({super.key});

  @override
  ConsumerState<PreferencesSettingsScreenV2> createState() => _PreferencesSettingsScreenV2State();
}

class _PreferencesSettingsScreenV2State extends ConsumerState<PreferencesSettingsScreenV2> {
  void _toggleNotifications(bool enable) {
    final current = ref.read(notificationConfigProvider);
    ref.read(notificationConfigProvider.notifier).updateConfig(current.copyWith(enabled: enable));
  }

  void _openLanguagePicker() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguagePickerScreenV2()));
  }

  void _openCurrencyPicker() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrencyPickerScreenV2()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final notifConfig = ref.watch(notificationConfigProvider);
    final posMode = ref.watch(posModeProvider);
    final appLocale = ref.watch(selectedAppLocaleProvider);
    final fiat = ref.watch(selectedFiatCurrencyProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.settingsPreferencesTitle),
      mainContent: ListView(
        children: [
          SettingsTappableRow(
            title: l10n.settingsPreferencesLanguage,
            subtitle: l10n.settingsPreferencesLanguageSubtitle,
            onTap: _openLanguagePicker,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(appLocale.displayName, style: text.smallParagraph?.copyWith(color: colors.textMuted)),
                const SizedBox(width: 4),
                SettingsTappableRowUtils.chevron(colors, color: colors.textMuted, size: 18),
              ],
            ),
          ),
          const SettingsDivider(),
          SettingsTappableRow(
            title: l10n.settingsPreferencesCurrency,
            subtitle: l10n.settingsPreferencesCurrencySubtitle,
            onTap: _openCurrencyPicker,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fiat.code, style: text.smallParagraph?.copyWith(color: colors.textMuted)),
                const SizedBox(width: 4),
                SettingsTappableRowUtils.chevron(colors, color: colors.textMuted, size: 18),
              ],
            ),
          ),
          const SettingsDivider(),
          SettingsSwitchRow(
            title: l10n.settingsPreferencesPosMode,
            subtitle: l10n.settingsPreferencesPosModeSubtitle,
            value: posMode,
            onChanged: (v) => ref.read(posModeProvider.notifier).setPosMode(v),
          ),
          const SettingsDivider(),
          SettingsSwitchRow(
            title: l10n.settingsPreferencesNotifications,
            subtitle: l10n.settingsPreferencesNotificationsSubtitle,
            value: notifConfig.enabled,
            onChanged: _toggleNotifications,
          ),
        ],
      ),
    );
  }
}
