import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_entry.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// What of the open account is still under way, in the phone's order: a
/// panel as tall as its rows, up to [maxHeight], then scrolling.
class InProgressPanel extends ConsumerWidget {
  const InProgressPanel({
    super.key,
    required this.transactions,
    required this.maxHeight,
    this.isFocused = false,
    this.rowsHaveKeys = true,
  });

  final List<TransactionEvent> transactions;
  final double maxHeight;

  /// Whether the keys are in this panel, and whether they are in the lists.
  final bool isFocused;
  final bool rowsHaveKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Panel(
      title: ref.watch(l10nProvider).desktopActivityInProgress,
      fillsHeight: false,
      isFocused: isFocused,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight - Panel.headerHeight - 1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = ActivityRowForm.of(constraints.maxWidth - 16);
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              children: [
                for (final tx in transactions)
                  ActivityEntry(key: ValueKey(tx.id), tx: tx, form: form, hasFocus: rowsHaveKeys),
              ],
            );
          },
        ),
      ),
    );
  }
}
