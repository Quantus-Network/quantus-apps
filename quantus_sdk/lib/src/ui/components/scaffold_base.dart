import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class ScaffoldBase extends StatelessWidget {
  final Widget? mainContent;
  final Widget? bottomContent;
  final List<Widget>? slivers;
  final Widget? appBar;
  final Widget? networkBanner;
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
    this.networkBanner,
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
    this.networkBanner,
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
    final colors = context.colorsV3;

    Widget bodyContent = Column(
      children: [
        ?networkBanner,
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

  Widget _buildChild(AppColorsV3 colors) {
    // Scrollable with refresh (CustomScrollView with slivers)
    if (onRefresh != null && slivers != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: colors.textContent,
        backgroundColor: colors.bgSurface,
        child: _withBottomContent(
          CustomScrollView(
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
      );
    }

    // Static content
    if (mainContent != null) {
      return _withBottomContent(Padding(padding: padding, child: mainContent!));
    }

    return const SizedBox.shrink();
  }

  Widget _withBottomContent(Widget content) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              const Positioned(left: 0, right: 0, bottom: 0, child: ToastHost()),
            ],
          ),
        ),
        ?bottomContent,
      ],
    );
  }
}
