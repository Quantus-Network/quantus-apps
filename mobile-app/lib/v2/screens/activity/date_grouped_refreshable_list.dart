import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/shared/utils/activity_date_groups.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

typedef DateGroupedItemBuilder<T> =
    Widget Function(BuildContext context, T item, {required bool isLastInGroup});

/// Pull-to-refresh list with date-group headers and optional load-more footer.
class DateGroupedRefreshableList<T> extends StatelessWidget {
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final List<ActivityDateGroup<T>> groups;
  final DateGroupedItemBuilder<T> itemBuilder;
  final bool showLoadMoreFooter;
  final String? emptyMessage;
  final double itemTopSpacing;

  const DateGroupedRefreshableList({
    super.key,
    required this.scrollController,
    required this.onRefresh,
    required this.groups,
    required this.itemBuilder,
    this.showLoadMoreFooter = false,
    this.emptyMessage,
    this.itemTopSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    if (groups.isEmpty && emptyMessage != null) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: colors.textPrimary,
        backgroundColor: colors.surface,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Text(
                    emptyMessage!,
                    style: text.paragraph?.copyWith(color: colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.textPrimary,
      backgroundColor: colors.surface,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: groups.length + (showLoadMoreFooter ? 1 : 0),
        itemBuilder: (context, i) {
          if (showLoadMoreFooter && i == groups.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Loader()),
            );
          }

          final group = groups[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i > 0) const SizedBox(height: 32),
              Text(group.label, style: text.receiveLabel?.copyWith(color: colors.textTertiary)),
              ...group.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final child = itemBuilder(
                  context,
                  item,
                  isLastInGroup: index == group.items.length - 1,
                );
                if (itemTopSpacing <= 0) return child;
                return Padding(
                  padding: EdgeInsets.only(top: itemTopSpacing),
                  child: child,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
