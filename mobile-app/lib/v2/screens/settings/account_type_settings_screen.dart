import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AccountTypeSettingsScreenV2 extends ConsumerWidget {
  const AccountTypeSettingsScreenV2({super.key});

  static List<({String title, String subtitle})> _upcomingFeatures(AppLocalizations l10n) {
    return [
      (title: l10n.settingsAccountTypeReversibleTitle, subtitle: l10n.settingsAccountTypeReversibleSubtitle),
      (title: l10n.settingsAccountTypeHighSecurityTitle, subtitle: l10n.settingsAccountTypeHighSecuritySubtitle),
      (title: l10n.settingsAccountTypeMultiSigTitle, subtitle: l10n.settingsAccountTypeMultiSigSubtitle),
      (title: l10n.settingsAccountTypeHardwareTitle, subtitle: l10n.settingsAccountTypeHardwareSubtitle),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final upcomingFeatures = _upcomingFeatures(l10n);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.settingsAccountTypeScreenTitle),
      mainContent: ListView(
        children: [
          Text(l10n.settingsAccountTypeIntro, style: text.smallParagraph?.copyWith(color: colors.textMuted)),
          const SizedBox(height: 40),
          for (var i = 0; i < upcomingFeatures.length; i++)
            _AccountFeatureBlock(
              colors: colors,
              text: text,
              comingSoonLabel: l10n.settingsAccountTypeComingSoon,
              title: upcomingFeatures[i].title,
              subtitle: upcomingFeatures[i].subtitle,
              showDividerBelow: i < upcomingFeatures.length - 1,
            ),
        ],
      ),
    );
  }
}

class _AccountFeatureBlock extends StatelessWidget {
  const _AccountFeatureBlock({
    required this.colors,
    required this.text,
    required this.comingSoonLabel,
    required this.title,
    required this.subtitle,
    required this.showDividerBelow,
  });

  final AppColorsV2 colors;
  final AppTextTheme text;
  final String comingSoonLabel;
  final String title;
  final String subtitle;
  final bool showDividerBelow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Opacity(
          opacity: 0.5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.smallTitle?.copyWith(fontWeight: FontWeight.w400)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _ComingSoonBadge(colors: colors, text: text, label: comingSoonLabel),
            ],
          ),
        ),
        if (showDividerBelow) const SettingsDivider(),
      ],
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge({required this.colors, required this.text, required this.label});

  final AppColorsV2 colors;
  final AppTextTheme text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.sheetBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.borderButton),
      ),
      alignment: Alignment.center,
      child: Text(label, style: text.detail?.copyWith(color: colors.textMuted)),
    );
  }
}
