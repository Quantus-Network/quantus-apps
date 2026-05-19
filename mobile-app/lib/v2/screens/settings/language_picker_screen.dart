import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/app_locale.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_picker_widgets.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class LanguagePickerScreenV2 extends ConsumerStatefulWidget {
  const LanguagePickerScreenV2({super.key});

  @override
  ConsumerState<LanguagePickerScreenV2> createState() =>
      _LanguagePickerScreenV2State();
}

class _LanguagePickerScreenV2State extends ConsumerState<LanguagePickerScreenV2> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppLocale> _filtered(String query) {
    final q = query.trim().toLowerCase();
    final list = List<AppLocale>.from(AppLocale.values);
    if (q.isEmpty) return list;
    return list.where((l) {
      return l.displayName.toLowerCase().contains(q) ||
          l.languageCode.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _onSelect(AppLocale locale) async {
    await ref.read(selectedAppLocaleProvider.notifier).select(locale);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final selected = ref.watch(selectedAppLocaleProvider);
    final filtered = _filtered(_searchController.text);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.settingsLanguageTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsPickerSearchField(
            controller: _searchController,
            colors: colors,
            text: text,
            hintText: l10n.settingsLanguageSearchHint,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceDeep,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 4,
                radius: const Radius.circular(25),
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.settingsLanguageNoMatch,
                          style: text.smallParagraph?.copyWith(
                            color: colors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SettingsDivider(
                          style: SettingsDividerStyle.currencyList,
                          padding: EdgeInsets.zero,
                        ),
                        itemBuilder: (context, index) {
                          final locale = filtered[index];
                          return SettingsPickerListTile(
                            label: locale.displayName,
                            selected: locale == selected,
                            colors: colors,
                            text: text,
                            onTap: () => _onSelect(locale),
                          );
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
