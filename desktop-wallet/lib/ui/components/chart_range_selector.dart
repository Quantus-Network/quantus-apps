import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/chart_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class ChartRangeSelector extends ConsumerWidget {
  const ChartRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final labels = {
      BalanceHistoryRange.week: l10n.chartRangeWeek,
      BalanceHistoryRange.month: l10n.chartRangeMonth,
      BalanceHistoryRange.quarter: l10n.chartRangeQuarter,
      BalanceHistoryRange.year: l10n.chartRangeYear,
      BalanceHistoryRange.all: l10n.chartRangeAll,
    };
    return SizedBox(
      width: 280,
      child: SegmentedControls<BalanceHistoryRange>(
        items: [
          for (final range in BalanceHistoryRange.values) SegmentedControlItem(value: range, label: labels[range]!),
        ],
        selectedValue: ref.watch(chartRangeProvider),
        onChanged: (range) => ref.read(chartRangeProvider.notifier).state = range,
      ),
    );
  }
}
