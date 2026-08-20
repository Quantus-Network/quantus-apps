import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;
import 'package:resonance_network_wallet/v2/components/network_status_banner.dart';

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

  const ScaffoldBase({
    super.key,
    this.appBar,
    this.networkBanner,
    this.padding = sdk.ScaffoldBase.defaultPadding,
    this.backgroundWidget,
    this.bottomContent,
    required Widget this.mainContent,
  }) : slivers = null,
       scrollController = null,
       scrollPhysics = null,
       onRefresh = null;

  const ScaffoldBase.refreshable({
    super.key,
    this.appBar,
    this.networkBanner,
    this.padding = sdk.ScaffoldBase.defaultPadding,
    this.backgroundWidget,
    this.scrollController,
    this.scrollPhysics = const AlwaysScrollableScrollPhysics(),
    this.bottomContent,
    required RefreshCallback this.onRefresh,
    required List<Widget> this.slivers,
  }) : mainContent = null;

  @override
  Widget build(BuildContext context) {
    final banner = networkBanner ?? const NetworkStatusBanner();

    if (onRefresh != null && slivers != null) {
      return sdk.ScaffoldBase.refreshable(
        appBar: appBar,
        networkBanner: banner,
        padding: padding,
        backgroundWidget: backgroundWidget,
        scrollController: scrollController,
        scrollPhysics: scrollPhysics,
        bottomContent: bottomContent,
        onRefresh: onRefresh!,
        slivers: slivers!,
      );
    }

    return sdk.ScaffoldBase(
      appBar: appBar,
      networkBanner: banner,
      padding: padding,
      backgroundWidget: backgroundWidget,
      bottomContent: bottomContent,
      mainContent: mainContent!,
    );
  }
}
