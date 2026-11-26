import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/generated/version.g.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/components/settings_group.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// About Quantus, as the phone's About has it: what Quantus is, its terms,
/// privacy policy and website, each opening in the browser, then the logo and
/// the app's version.
class AboutSheet extends ConsumerWidget {
  const AboutSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    void open(Uri url) => unawaited(ref.read(openExternalUrlProvider)(url));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.settingsAboutIntro, style: text.body.copyWith(color: colors.textMuted)),
        const SizedBox(height: 24),
        SettingsGroup(
          rows: [
            for (final (title, address, url) in [
              (l10n.settingsAboutTerms, l10n.settingsAboutTermsSubtitle, termsOfServiceUrl),
              (l10n.settingsAboutPrivacy, l10n.settingsAboutPrivacySubtitle, privacyPolicyUrl),
              (l10n.settingsAboutWebsite, l10n.settingsAboutWebsiteSubtitle, websiteUrl),
            ])
              SettingsRow.action(title: title, subtitle: address, onPressed: () => open(url)),
          ],
        ),
        const SizedBox(height: 28),
        Image.asset('assets/quantus_orange_logo.png', height: 32),
        const SizedBox(height: 12),
        Text(
          l10n.desktopFooterVersion(appVersion),
          textAlign: TextAlign.center,
          style: text.caption.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}
