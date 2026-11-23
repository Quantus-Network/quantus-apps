import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_entry.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_row_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// What of the open account is still under way, in the phone's order, the
/// swap from it first, as the phone pins it: a panel as tall as its rows, up
/// to [maxHeight], then scrolling. Scrolled
/// near its end, it asks for the next page, as Activity does: what is
/// scheduled comes a page at a time with what is settled.
class InProgressPanel extends ConsumerStatefulWidget {
  const InProgressPanel({
    super.key,
    required this.transactions,
    required this.maxHeight,
    this.hasSwap = false,
    this.isFocused = false,
    this.rowsHaveKeys = true,
  });

  final List<TransactionEvent> transactions;
  final double maxHeight;

  /// Whether the swap being followed is from this account, and is listed.
  final bool hasSwap;

  /// Whether the keys are in this panel, and whether they are in the lists.
  final bool isFocused;
  final bool rowsHaveKeys;

  @override
  ConsumerState<InProgressPanel> createState() => _InProgressPanelState();
}

class _InProgressPanelState extends ConsumerState<InProgressPanel> {
  late final _scroll = ScrollController()..addListener(_fetchNearEnd);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _fetchNearEnd() => fetchMoreActivityNear(ref, _scroll.position);

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: ref.watch(l10nProvider).desktopActivityInProgress,
      fillsHeight: false,
      isFocused: widget.isFocused,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight - Panel.headerHeight - 1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = ActivityRowForm.of(constraints.maxWidth - 16);
            return ListView(
              controller: _scroll,
              shrinkWrap: true,
              padding: const EdgeInsets.all(8),
              children: [
                if (widget.hasSwap) SwapEntry(form: form, hasFocus: widget.rowsHaveKeys),
                for (final tx in widget.transactions)
                  ActivityEntry(key: ValueKey(tx.id), tx: tx, form: form, hasFocus: widget.rowsHaveKeys),
              ],
            );
          },
        ),
      ),
    );
  }
}
