import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/app_locale.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_picker_screen.dart';

class LanguagePickerScreenV2 extends ConsumerWidget {
  const LanguagePickerScreenV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final selected = ref.watch(selectedAppLocaleProvider);

    return SettingsPickerScreen<AppLocale>(
      title: l10n.settingsLanguageTitle,
      searchHint: l10n.settingsLanguageSearchHint,
      emptyMessage: l10n.settingsLanguageNoMatch,
      items: AppLocale.values,
      selected: selected,
      labelBuilder: (locale) => locale.displayName,
      filter: (locale, query) {
        return locale.displayName.toLowerCase().contains(query) ||
            locale.languageCode.toLowerCase().contains(query);
      },
      onSelect: (locale) async {
        try {
          await ref.read(selectedAppLocaleProvider.notifier).select(locale);
          if (context.mounted) {
            Navigator.pop(context);
          }
        } catch (e) {
          debugPrint('error selecting locale: $e');
          if (context.mounted) {
            context.showErrorToaster(message: 'Error selecting locale: $e');
          }
        }
      },
    );
  }
}
