import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class ScreenTitle {
  final String title;
  final double spacing;

  ScreenTitle({required this.title, this.spacing = 20.0});
}

class ScaffoldBase extends StatelessWidget {
  final Widget child;
  final String? appBar;
  final ScreenTitle? screenTitle;
  final List<Widget>? decorations;
  final EdgeInsetsGeometry padding;
  final double backdropBlur;
  final double dim;
  final bool extendBodyBehingAppBar;

  const ScaffoldBase({
    super.key,
    this.appBar,
    this.screenTitle,
    this.extendBodyBehingAppBar = true,
    this.backdropBlur = 12.0,
    this.decorations,
    this.dim = 0.25,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar != null ? WalletAppBar(title: appBar!) : null,
      backgroundColor: context.themeColors.background,
      body: Stack(
        children: [
          if (decorations != null) ...decorations!,
          Positioned(
            child: Container(
              decoration: BoxDecoration(color: Colors.black.useOpacity(dim)),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: backdropBlur,
              sigmaY: backdropBlur,
            ),
            child: SafeArea(
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (screenTitle != null) ...[
                      const SizedBox(height: 21.0),
                      Text(
                        screenTitle!.title,
                        style: context.themeText.smallTitle,
                      ),
                      SizedBox(height: screenTitle!.spacing),
                    ],
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
