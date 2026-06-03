import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/generated/version.g.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_tappable_row.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AboutQuantusScreenV2 extends ConsumerWidget {
  const AboutQuantusScreenV2({super.key});

  static Uri _uriForAboutLink(({String title, String subtitle, String path}) link) {
    if (link.path.isEmpty) {
      return Uri.parse(AppConstants.websiteBaseUrl);
    }
    return Uri.parse('${AppConstants.websiteBaseUrl}${link.path}');
  }

  static List<({String title, String subtitle, String path})> _externalLinks(AppLocalizations l10n) {
    return [
      (title: l10n.settingsAboutTerms, subtitle: l10n.settingsAboutTermsSubtitle, path: '/terms'),
      (title: l10n.settingsAboutPrivacy, subtitle: l10n.settingsAboutPrivacySubtitle, path: '/privacy-policy'),
      (title: l10n.settingsAboutWebsite, subtitle: l10n.settingsAboutWebsiteSubtitle, path: ''),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final externalLinks = _externalLinks(l10n);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.settingsAboutScreenTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                Text(
                  l10n.settingsAboutIntro,
                  style: text.smallParagraph?.copyWith(color: colors.textMuted, height: 1.35),
                ),
                const SizedBox(height: 40),
                for (final entry in externalLinks.asMap().entries) ...[
                  SettingsTappableRow(
                    title: entry.value.title,
                    subtitle: entry.value.subtitle,
                    onTap: () => openUrl(_uriForAboutLink(entry.value).toString()),
                    trailing: SettingsTappableRowUtils.externalLink(colors),
                  ),
                  if (entry.key < externalLinks.length - 1) const SettingsDivider(),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/v2/quantus_orange_logo.png', height: 40),
              const SizedBox(height: 14),
              Text(
                l10n.settingsAboutVersion(appVersion, appBuildNumber),
                textAlign: TextAlign.center,
                style: text.paragraph?.copyWith(color: colors.textMuted, fontSize: 16, height: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}
