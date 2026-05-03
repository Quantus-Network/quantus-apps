import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/models/fiat_currency.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class CurrencyPickerScreenV2 extends ConsumerStatefulWidget {
  const CurrencyPickerScreenV2({super.key});

  @override
  ConsumerState<CurrencyPickerScreenV2> createState() => _CurrencyPickerScreenV2State();
}

class _CurrencyPickerScreenV2State extends ConsumerState<CurrencyPickerScreenV2> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FiatCurrency> _filtered(String query) {
    final q = query.trim().toLowerCase();
    final list = List<FiatCurrency>.from(FiatCurrency.values);
    if (q.isEmpty) return list;
    return list.where((c) {
      final line = c.line.toLowerCase();
      return line.contains(q) || c.code.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _onSelect(FiatCurrency c) async {
    await ref.read(selectedFiatCurrencyProvider.notifier).select(c);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final selected = ref.watch(selectedFiatCurrencyProvider);
    final filtered = _filtered(_searchController.text);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Currency'),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(controller: _searchController, colors: colors, text: text, onChanged: (_) => setState(() {})),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 4,
                radius: const Radius.circular(25),
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No currencies match your search',
                          style: text.smallParagraph?.copyWith(color: colors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SettingsDivider(style: SettingsDividerStyle.currencyList, padding: EdgeInsets.zero),
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          final isSelected = c == selected;

                          return _CurrencyListTile(
                            label: c.line,
                            selected: isSelected,
                            colors: colors,
                            text: text,
                            onTap: () => _onSelect(c),
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.colors, required this.text, required this.onChanged});

  final TextEditingController controller;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 8),
        decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: colors.textLabel),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: text.smallParagraph,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search',
                  hintStyle: text.smallParagraph?.copyWith(color: colors.textLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyListTile extends StatelessWidget {
  const _CurrencyListTile({
    required this.label,
    required this.selected,
    required this.colors,
    required this.text,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppColorsV2 colors;
  final AppTextTheme text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = colors.accentOrange;
    final fg = selected ? accent : colors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(label, style: text.paragraph?.copyWith(color: fg, height: 1.2)),
              ),
              if (selected) ...[const SizedBox(width: 12), Icon(Icons.check, size: 18, color: accent)],
            ],
          ),
        ),
      ),
    );
  }
}
