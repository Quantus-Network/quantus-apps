import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/network_status_banner.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

const defaultPadding = EdgeInsets.symmetric(horizontal: 24.0);

class ScaffoldBase extends StatelessWidget {
  final Widget? child;
  final List<Widget>? slivers;
  final Widget? appBar;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final RefreshCallback? onRefresh;
  final EdgeInsetsGeometry padding;
  final Widget? backgroundWidget;

  // Default constructor - static content
  const ScaffoldBase({
    super.key,
    this.appBar,
    this.padding = defaultPadding,
    this.backgroundWidget,
    required Widget this.child,
  }) : slivers = null,
       scrollController = null,
       scrollPhysics = null,
       onRefresh = null;

  // Scrollable constructor - SingleChildScrollView without refresh
  const ScaffoldBase.scrollable({
    super.key,
    this.appBar,
    this.padding = defaultPadding,
    this.backgroundWidget,
    this.scrollController,
    this.scrollPhysics = const AlwaysScrollableScrollPhysics(),
    required Widget this.child,
  }) : slivers = null,
       onRefresh = null;

  // Refreshable constructor - CustomScrollView with pull-to-refresh
  const ScaffoldBase.refreshable({
    super.key,
    this.appBar,
    this.padding = defaultPadding,
    this.backgroundWidget,
    this.scrollController,
    this.scrollPhysics = const AlwaysScrollableScrollPhysics(),
    required RefreshCallback this.onRefresh,
    required List<Widget> this.slivers,
  }) : child = null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget bodyContent = Column(
      children: [
        const NetworkStatusBanner(),
        if (appBar != null) Padding(padding: padding, child: appBar!),
        Expanded(child: _buildChild(colors)),
      ],
    );

    Widget scaffoldBody = SafeArea(bottom: false, child: bodyContent);

    if (backgroundWidget != null) {
      scaffoldBody = Stack(fit: StackFit.expand, children: [backgroundWidget!, scaffoldBody]);
    } else {
      scaffoldBody = GradientBackground(child: scaffoldBody);
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
        child: CustomScrollView(
          controller: scrollController,
          physics: scrollPhysics ?? const AlwaysScrollableScrollPhysics(),
          slivers: slivers!,
        ),
      );
    }

    // Scrollable with SingleChildScrollView (no refresh)
    if (child != null && scrollController != null && onRefresh == null) {
      return SingleChildScrollView(
        controller: scrollController,
        physics: scrollPhysics ?? const AlwaysScrollableScrollPhysics(),
        padding: padding,
        child: child!,
      );
    }

    // Static content
    if (child != null) {
      return Padding(padding: padding, child: child!);
    }

    return const SizedBox.shrink();
  }
}
