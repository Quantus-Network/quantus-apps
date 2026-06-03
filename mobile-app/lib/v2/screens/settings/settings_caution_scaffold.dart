import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_checkbox.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_list_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class SettingsCautionScaffoldData {
  final String headline;
  final List<String> bulletItems;
  final String checkboxLabel;

  const SettingsCautionScaffoldData({required this.headline, required this.bulletItems, required this.checkboxLabel});

  factory SettingsCautionScaffoldData.recoveryPhrase(AppLocalizations l10n) {
    return SettingsCautionScaffoldData(
      headline: l10n.createWalletCautionHeadline,
      bulletItems: [l10n.createWalletCautionBullet1, l10n.createWalletCautionBullet2, l10n.createWalletCautionBullet3],
      checkboxLabel: l10n.createWalletCautionCheckboxLabel,
    );
  }

  factory SettingsCautionScaffoldData.walletReset(AppLocalizations l10n) {
    return SettingsCautionScaffoldData(
      headline: l10n.settingsResetCautionHeadline,
      bulletItems: [
        l10n.settingsResetCautionBullet1,
        l10n.settingsResetCautionBullet2,
        l10n.settingsResetCautionBullet3,
      ],
      checkboxLabel: l10n.settingsResetCautionCheckbox,
    );
  }
}

class SettingsCautionScaffold extends StatelessWidget {
  final String appBarTitle;
  final String continueLabel;
  final bool checkboxChecked;
  final VoidCallback onCheckboxChanged;
  final VoidCallback onContinue;
  final SettingsCautionScaffoldData data;
  final SettingsDividerStyle betweenBulletsStyle;
  final bool continueButtonLoading;

  const SettingsCautionScaffold({
    super.key,
    required this.appBarTitle,
    required this.checkboxChecked,
    required this.onCheckboxChanged,
    required this.onContinue,
    required this.data,
    required this.continueLabel,
    this.betweenBulletsStyle = SettingsDividerStyle.list,
    this.continueButtonLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    final headlineStyle = text.mediumTitle?.copyWith(fontSize: 28);

    return ScaffoldBase(
      appBar: V2AppBar(title: appBarTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          children: [
            Icon(Icons.warning_amber_outlined, size: 40, color: colors.accentOrange),
            const SizedBox(height: 16),
            Text(data.headline, textAlign: TextAlign.center, style: headlineStyle),
            const SizedBox(height: 40),
            for (var i = 0; i < data.bulletItems.length; i++) ...[
              SettingsListRow(label: (i + 1).toString().padLeft(2, '0'), content: data.bulletItems[i]),
              if (i < data.bulletItems.length - 1) SettingsDivider(style: betweenBulletsStyle),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomContent: _SettingsCautionBottom(
        checkboxLabel: data.checkboxLabel,
        continueLabel: continueLabel,
        checked: checkboxChecked,
        onCheckboxChanged: onCheckboxChanged,
        onContinue: onContinue,
        continueButtonLoading: continueButtonLoading,
      ),
    );
  }
}

class _SettingsCautionBottom extends StatelessWidget {
  const _SettingsCautionBottom({
    required this.checkboxLabel,
    required this.continueLabel,
    required this.checked,
    required this.onCheckboxChanged,
    required this.onContinue,
    required this.continueButtonLoading,
  });

  final String checkboxLabel;
  final String continueLabel;
  final bool checked;
  final VoidCallback onCheckboxChanged;
  final VoidCallback onContinue;
  final bool continueButtonLoading;

  @override
  Widget build(BuildContext context) {
    return ScaffoldBaseBottomContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsCheckbox(checked: checked, label: checkboxLabel, onTap: onCheckboxChanged),
          const SizedBox(height: 32),
          QuantusButton.simple(
            label: continueLabel,
            onTap: onContinue,
            variant: ButtonVariant.primary,
            isDisabled: !checked,
            isLoading: continueButtonLoading,
          ),
        ],
      ),
    );
  }
}
