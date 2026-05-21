import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_picker_widgets.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Searchable list for choosing a single settings value (language, currency, etc.).
class SettingsPickerScreen<T> extends StatefulWidget {
  const SettingsPickerScreen({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    required this.items,
    required this.selected,
    required this.labelBuilder,
    required this.onSelect,
    required this.errorMessageBuilder,
    this.filter,
  });

  final String title;
  final String searchHint;
  final String emptyMessage;
  final List<T> items;
  final T selected;
  final String Function(T) labelBuilder;
  final bool Function(T item, String query)? filter;
  final Future<void> Function(T) onSelect;
  final String Function(String error) errorMessageBuilder;

  @override
  State<SettingsPickerScreen<T>> createState() => _SettingsPickerScreenState<T>();
}

class _SettingsPickerScreenState<T> extends State<SettingsPickerScreen<T>> {
  final _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> _filtered(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<T>.from(widget.items);
    return widget.items.where((item) {
      if (widget.filter != null) {
        return widget.filter!(item, q);
      }
      return widget.labelBuilder(item).toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final filtered = _filtered(_searchController.text);

    return ScaffoldBase(
      appBar: V2AppBar(title: widget.title),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsPickerSearchField(
            controller: _searchController,
            colors: colors,
            text: text,
            hintText: widget.searchHint,
            onChanged: (_) => setState(() {}),
          ),
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
                          widget.emptyMessage,
                          style: text.smallParagraph?.copyWith(color: colors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SettingsDivider(style: SettingsDividerStyle.currencyList, padding: EdgeInsets.zero),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return SettingsPickerListTile(
                            label: widget.labelBuilder(item),
                            selected: item == widget.selected,
                            colors: colors,
                            text: text,
                            onTap: () async {
                              if (_isLoading) return;

                              setState(() => _isLoading = true);

                              try {
                                await widget.onSelect(item);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                quantusDebugPrint('[SettingsPickerScreen] error selecting item: $e');
                                if (context.mounted) {
                                  context.showErrorToaster(message: widget.errorMessageBuilder(e.toString()));
                                }
                              } finally {
                                if (mounted) setState(() => _isLoading = false);
                              }
                            },
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
