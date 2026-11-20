import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_entry.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_skeleton.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/live_data_scope.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_dates.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/active_account_transactions_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// The open account's settled activity, under its days, newest first.
///
/// Waiting for it is kind to the eye: nothing shows for the first
/// [revealAfter], so a quick load just appears; after that the rows' shapes
/// breathe ([ActivitySkeleton]) for at least [shownAtLeast], then the rows
/// fade in. Near the list's end the next page is fetched, its shapes at the
/// end meanwhile. ↻ refreshes it; while that, or any reload of rows already
/// shown, runs, a light runs along the header and the rows stay. A reload
/// that fails leaves a note over them, with Try Again.
class ActivityPanel extends ConsumerStatefulWidget {
  const ActivityPanel({super.key, this.isFocused = false, this.rowsHaveKeys = true});

  /// Whether the keys are in this panel: its border is lighter.
  final bool isFocused;

  /// Whether the keys are in the lists, so an open row's backing is strong.
  final bool rowsHaveKeys;

  static const refreshKey = Key('activity-refresh');
  static const loadingMoreKey = Key('activity-loading-more');

  static const revealAfter = Duration(milliseconds: 400);
  static const shownAtLeast = Duration(milliseconds: 500);
  static const fadeIn = Duration(milliseconds: 150);

  /// How near the list's end the next page is asked for.
  static const double fetchWithin = 400;

  @override
  ConsumerState<ActivityPanel> createState() => _ActivityPanelState();
}

class _ActivityPanelState extends ConsumerState<ActivityPanel> {
  final _scroll = ScrollController();

  /// Whether the skeleton shows, and whether it has shown long enough.
  bool _isRevealed = false;
  bool _hasShownLongEnough = false;
  Timer? _reveal;
  Timer? _minimum;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_fetchNearEnd);
    if (ref.read(activityViewProvider).isLoading) _startWaiting();
    _fetchNearEndOnceLaidOut();
  }

  @override
  void dispose() {
    _reveal?.cancel();
    _minimum?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _startWaiting() {
    _reveal?.cancel();
    _minimum?.cancel();
    _isRevealed = false;
    _hasShownLongEnough = false;
    _reveal = Timer(ActivityPanel.revealAfter, () {
      if (!mounted) return;
      setState(() => _isRevealed = true);
      _minimum = Timer(ActivityPanel.shownAtLeast, () {
        if (mounted) setState(() => _hasShownLongEnough = true);
      });
    });
  }

  /// The skeleton shows while loading once revealed, and stays until it has
  /// shown long enough.
  bool _showsSkeleton(bool isLoading) => _isRevealed && (isLoading || !_hasShownLongEnough);

  void _fetchNearEnd() {
    if (_scroll.hasClients) fetchMoreActivityNear(ref, _scroll.position);
  }

  /// Rows that do not fill the list leave no end to scroll to, as when what
  /// is in progress came in without anything settled: once laid out, they
  /// are measured as a scroll would.
  void _fetchNearEndOnceLaidOut() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _fetchNearEnd();
  });

  @override
  Widget build(BuildContext context) {
    // New rows, or more being there, are measured once laid out. A page that
    // failed changes neither, so it is not asked for again on its own.
    ref.listen(
      activityViewProvider.select(
        (view) => (view.value?.settled.length, view.value?.inProgress.length, view.value?.hasMore),
      ),
      (_, _) => _fetchNearEndOnceLaidOut(),
    );
    ref.listen(activityViewProvider.select((view) => view.isLoading), (wasLoading, isLoading) {
      if (isLoading && wasLoading != true) {
        setState(_startWaiting);
      } else if (!isLoading) {
        _reveal?.cancel();
        // Never revealed: nothing to keep showing.
        if (!_isRevealed) _minimum?.cancel();
      }
    });
    final l10n = ref.watch(l10nProvider);
    final view = ref.watch(activityViewProvider);
    final isRefreshing = ref.watch(walletRefreshingProvider);

    final Widget body;
    if (_showsSkeleton(view.isLoading)) {
      body = const ActivitySkeleton(key: ValueKey('skeleton'));
    } else {
      body = switch (view) {
        AsyncValue(isLoading: true) => const SizedBox.shrink(key: ValueKey('waiting')),
        AsyncValue(:final error?) => _Failed(key: const ValueKey('failed'), error: error, l10n: l10n),
        AsyncValue(:final value?) when value.settled.isEmpty && value.inProgress.isEmpty => Column(
          key: const ValueKey('empty'),
          children: [
            // Where the list holds it, over the rows.
            if (value.reloadFailure != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _RefreshFailed(l10n: l10n),
              ),
            Expanded(
              child: Center(
                child: Text(
                  l10n.activityEmpty,
                  style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted),
                ),
              ),
            ),
          ],
        ),
        AsyncValue(:final value?) => _List(
          key: const ValueKey('list'),
          view: value,
          scroll: _scroll,
          l10n: l10n,
          rowsHaveKeys: widget.rowsHaveKeys,
        ),
        _ => const SizedBox.shrink(key: ValueKey('waiting')),
      };
    }

    return Panel(
      title: l10n.activityTitle,
      isBusy: (isRefreshing || (view.value?.isReloading ?? false)) && view.hasValue,
      isFocused: widget.isFocused,
      trailing: ToolbarAction.symbol(
        key: ActivityPanel.refreshKey,
        symbol: CupertinoIcons.arrow_clockwise,
        label: l10n.desktopMenuRefresh,
        iconOnly: true,
        onPressed: () => unawaited(refreshWallet(ref)),
      ),
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : ActivityPanel.fadeIn,
        // From the top, where the rows go: the skeleton is no taller than it
        // needs.
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
        child: body,
      ),
    );
  }
}

/// Asks for the next page of the open account's activity when [position] is
/// within [ActivityPanel.fetchWithin] of its end (as when its rows do not
/// fill it), there is more, and none is being fetched. Activity and In
/// progress both show from the same pages, so either asks.
void fetchMoreActivityNear(WidgetRef ref, ScrollPosition position) {
  final view = ref.read(activityViewProvider).value;
  if (view == null || !view.hasMore || view.isLoadingMore) return;
  if (position.pixels < position.maxScrollExtent - ActivityPanel.fetchWithin) return;
  unawaited(readActiveAccountPaginationNotifier(ref, TransactionFilter.all)?.fetchMore());
}

/// The settled activity under its days, with the next page's shapes at the
/// end while it loads.
class _List extends StatelessWidget {
  const _List({super.key, required this.view, required this.scroll, required this.l10n, required this.rowsHaveKeys});

  final ActivityView view;
  final ScrollController scroll;
  final AppLocalizations l10n;
  final bool rowsHaveKeys;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final days = activityDaysOf(view.settled, l10n, l10n.localeName);
    return LayoutBuilder(
      builder: (context, constraints) {
        final form = ActivityRowForm.of(constraints.maxWidth - 16);
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          children: [
            if (view.reloadFailure != null) _RefreshFailed(l10n: l10n),
            for (final (index, day) in days.indexed) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(8, index == 0 ? 14 : 20, 8, 6),
                child: CapsText(
                  day.label,
                  style: context.themeTextV3.caption.copyWith(
                    color: colors.textMuted2,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              for (final tx in day.transactions)
                ActivityEntry(key: ValueKey(tx.id), tx: tx, form: form, hasFocus: rowsHaveKeys),
            ],
            if (view.isLoadingMore) const ActivitySkeleton(key: ActivityPanel.loadingMoreKey, rows: 2),
          ],
        );
      },
    );
  }
}

/// Over the rows kept on screen, or the word that there are none: their
/// refresh failed, and a way to try again.
class _RefreshFailed extends ConsumerWidget {
  const _RefreshFailed({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.desktopActivityRefreshFailed,
              style: context.themeTextV3.body.copyWith(color: context.colorsV3.semanticEmber),
            ),
          ),
          ToolbarAction.symbol(
            symbol: CupertinoIcons.arrow_clockwise,
            label: l10n.commonTryAgain,
            onPressed: () => unawaited(refreshWallet(ref)),
          ),
        ],
      ),
    );
  }
}

/// What failed to load, and a way to try again.
class _Failed extends ConsumerWidget {
  const _Failed({super.key, required this.error, required this.l10n});

  final Object error;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.desktopActivityLoadFailed, style: text.body.copyWith(color: colors.semanticEmber)),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.textMuted2),
            ),
            const SizedBox(height: 10),
            ToolbarAction.symbol(
              symbol: CupertinoIcons.arrow_clockwise,
              label: l10n.commonTryAgain,
              onPressed: () => unawaited(refreshWallet(ref)),
            ),
          ],
        ),
      ),
    );
  }
}
