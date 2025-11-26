import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/network_status_banner.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';

class ScaffoldBase extends StatelessWidget {
  final Widget? child;
  final List<Widget>? slivers;
  final WalletAppBar? appBar;
  final List<Widget>? decorations;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final RefreshCallback? onRefresh;
  final EdgeInsetsGeometry padding;
  final double backdropBlur;
  final double dim;
  final bool extendBodyBehindAppBar;
  final bool extendBodyBehindNavBar;

  // Default constructor - static content
  const ScaffoldBase({
    super.key,
    this.appBar,
    this.extendBodyBehindAppBar = true,
    this.extendBodyBehindNavBar = false,
    this.backdropBlur = 12.0,
    this.decorations,
    this.dim = 0.25,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0),
    required Widget this.child,
  }) : slivers = null,
       scrollController = null,
       scrollPhysics = null,
       onRefresh = null;

  // Scrollable constructor - SingleChildScrollView without refresh
  const ScaffoldBase.scrollable({
    super.key,
    this.appBar,
    this.extendBodyBehindAppBar = true,
    this.extendBodyBehindNavBar = false,
    this.backdropBlur = 12.0,
    this.decorations,
    this.dim = 0.25,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0),
    required ScrollController this.scrollController,
    this.scrollPhysics = const AlwaysScrollableScrollPhysics(),
    required Widget this.child,
  }) : slivers = null,
       onRefresh = null;

  // Refreshable constructor - CustomScrollView with pull-to-refresh
  const ScaffoldBase.refreshable({
    super.key,
    this.appBar,
    this.extendBodyBehindAppBar = true,
    this.extendBodyBehindNavBar = false,
    this.backdropBlur = 12.0,
    this.decorations,
    this.dim = 0.25,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0),
    required ScrollController this.scrollController,
    this.scrollPhysics = const AlwaysScrollableScrollPhysics(),
    required RefreshCallback this.onRefresh,
    required List<Widget> this.slivers,
  }) : child = null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      backgroundColor: context.themeColors.background,
      body: Stack(
        children: [
          if (decorations != null) ...decorations!,
          Positioned.fill(
            child: Container(decoration: BoxDecoration(color: Colors.black.useOpacity(dim))),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: backdropBlur, sigmaY: backdropBlur),
            child: SafeArea(
              bottom: !extendBodyBehindNavBar,
              child: Column(
                children: [
                  const NetworkStatusBanner(),
                  Expanded(
                    child: Padding(padding: padding, child: _buildChild()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChild() {
    // Static content
    if (child != null && scrollController == null) {
      return child!;
    }

    // Scrollable with SingleChildScrollView (no refresh)
    if (child != null && scrollController != null && onRefresh == null) {
      return SingleChildScrollView(
        controller: scrollController,
        physics: scrollPhysics ?? const AlwaysScrollableScrollPhysics(),
        child: child!,
      );
    }

    // Scrollable with refresh (CustomScrollView with slivers)
    if (onRefresh != null && slivers != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: const Color(0xFF0CE6ED),
        backgroundColor: Colors.black,
        child: CustomScrollView(
          controller: scrollController,
          physics: scrollPhysics ?? const AlwaysScrollableScrollPhysics(),
          slivers: slivers!,
        ),
      );
    }

    // Fallback to child if something unexpected happens
    return child ?? const SizedBox.shrink();
  }
}
