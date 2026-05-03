import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AccountTypeSettingsScreenV2 extends StatelessWidget {
  const AccountTypeSettingsScreenV2({super.key});

  static const _intro =
      'Advanced account features are coming soon. These will give you greater control over how transactions are authorised and secured.';

  static const _upcomingFeatures = <({String title, String subtitle})>[
    (title: 'Reversible Transactions', subtitle: 'Reverse your sends within a time window'),
    (title: 'High Security Account', subtitle: 'Guardian approval required'),
    (title: 'Multi-Signature', subtitle: 'Multiple approvals required'),
    (title: 'Hardware Wallet', subtitle: 'Pair a hardware device'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Account Type'),
      mainContent: ListView(
        children: [
          Text(_intro, style: text.smallParagraph?.copyWith(color: colors.textMuted)),
          const SizedBox(height: 40),
          for (var i = 0; i < _upcomingFeatures.length; i++)
            _AccountFeatureBlock(
              colors: colors,
              text: text,
              title: _upcomingFeatures[i].title,
              subtitle: _upcomingFeatures[i].subtitle,
              showDividerBelow: i < _upcomingFeatures.length - 1,
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
    required this.title,
    required this.subtitle,
    required this.showDividerBelow,
  });

  final AppColorsV2 colors;
  final AppTextTheme text;
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
              _ComingSoonBadge(colors: colors, text: text),
            ],
          ),
        ),
        if (showDividerBelow) const SettingsDivider(),
      ],
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge({required this.colors, required this.text});

  final AppColorsV2 colors;
  final AppTextTheme text;

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
      child: Text('Coming Soon', style: text.detail?.copyWith(color: colors.textMuted)),
    );
  }
}
