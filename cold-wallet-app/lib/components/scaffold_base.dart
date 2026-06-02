import 'package:flutter/material.dart';
import 'package:quantus_cold_wallet/components/base_background.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';

class ScaffoldBase extends StatelessWidget {
  final Widget? mainContent;
  final Widget? bottomContent;
  final List<Widget>? slivers;
  final Widget? appBar;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final RefreshCallback? onRefresh;
  final EdgeInsetsGeometry padding;
  final Widget? backgroundWidget;

  static const defaultPadding = EdgeInsets.symmetric(horizontal: 24.0);

  // Default constructor - static content
  const ScaffoldBase({
    super.key,
    this.appBar,
    this.padding = defaultPadding,
    this.backgroundWidget,
    this.bottomContent,
    required Widget this.mainContent,
  }) : slivers = null,
       scrollController = null,
       scrollPhysics = null,
       onRefresh = null;

  // Refreshable constructor - CustomScrollView with pull-to-refresh
  const ScaffoldBase.refreshable({
    super.key,
    this.appBar,
    this.padding = defaultPadding,
    this.backgroundWidget,
    this.scrollController,
    this.scrollPhysics = const AlwaysScrollableScrollPhysics(),
    this.bottomContent,
    required RefreshCallback this.onRefresh,
    required List<Widget> this.slivers,
  }) : mainContent = null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget bodyContent = Column(
      children: [
        if (appBar != null) Padding(padding: padding, child: appBar!),
        Expanded(child: _buildChild(colors)),
      ],
    );

    Widget scaffoldBody = SafeArea(child: bodyContent);

    if (backgroundWidget != null) {
      scaffoldBody = Stack(fit: StackFit.expand, children: [backgroundWidget!, scaffoldBody]);
    } else {
      scaffoldBody = BaseBackground(child: scaffoldBody);
    }

    return Scaffold(body: scaffoldBody);
  }

  Widget _buildChild(AppColorsV2 colors) {
    // Scrollable with refresh (CustomScrollView with slivers)
    if (onRefresh != null && slivers != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: colors.textPrimary,
        backgroundColor: colors.surface,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: scrollController,
                physics: scrollPhysics ?? const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: padding,
                    sliver: SliverList(delegate: SliverChildListDelegate(slivers!)),
                  ),
                ],
              ),
            ),
            ?bottomContent,
          ],
        ),
      );
    }

    // Static content
    if (mainContent != null) {
      return Column(
        children: [
          Expanded(
            child: Padding(padding: padding, child: mainContent!),
          ),
          ?bottomContent,
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
