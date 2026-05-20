import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_picker_screen.dart';

class CurrencyPickerScreenV2 extends ConsumerWidget {
  const CurrencyPickerScreenV2({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final selected = ref.watch(selectedFiatCurrencyProvider);

    return SettingsPickerScreen<FiatCurrency>(
      title: l10n.settingsCurrencyTitle,
      searchHint: l10n.settingsCurrencySearchHint,
      emptyMessage: l10n.settingsCurrencyNoMatch,
      items: FiatCurrency.values,
      selected: selected,
      labelBuilder: (currency) => currency.line,
      filter: (currency, query) {
        final line = currency.line.toLowerCase();
        return line.contains(query) || currency.code.toLowerCase().contains(query);
      },
      onSelect: ref.read(selectedFiatCurrencyProvider.notifier).select,
      errorMessageBuilder: l10n.settingsCurrencyError,
    );
  }
}
