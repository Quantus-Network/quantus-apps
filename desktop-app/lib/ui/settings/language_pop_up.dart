import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/components/pop_up_button.dart';
import 'package:wallet_core/models/app_locale.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The app's language as a pop-up button, each language in its own name.
/// A choice that cannot be kept is passed to [onFailed].
class LanguagePopUp extends ConsumerWidget {
  const LanguagePopUp({super.key, required this.onFailed});

  final ValueChanged<Object> onFailed;

  Future<void> _select(WidgetRef ref, AppLocale locale) async {
    try {
      await ref.read(selectedAppLocaleProvider.notifier).select(locale);
    } catch (e) {
      onFailed(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopUpButton<AppLocale>(
      semanticLabel: ref.watch(l10nProvider).settingsPreferencesLanguage,
      items: [for (final locale in AppLocale.values) PopUpItem(locale, locale.displayName)],
      value: ref.watch(selectedAppLocaleProvider),
      onSelected: (locale) => _select(ref, locale),
    );
  }
}
