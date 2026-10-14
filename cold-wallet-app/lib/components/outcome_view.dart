import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';

/// Terminal screen layout shared by Key Created, Unreadable and Rejected
/// (Figma Cold Wallet): a glyph, a title, a body, then
/// whatever rows or cards the screen adds, with its buttons pinned below.
class OutcomeView extends StatelessWidget {
  final String appBarTitle;
  final bool showBackButton;
  final ColdIcons glyph;
  final Color glyphColor;
  final String title;
  final String body;
  final Widget bottom;

  /// Below the body, stretched to the content width.
  final List<Widget> children;

  const OutcomeView({
    super.key,
    required this.appBarTitle,
    this.showBackButton = true,
    required this.glyph,
    required this.glyphColor,
    required this.title,
    required this.body,
    required this.bottom,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return ScaffoldBase(
      appBar: V2AppBar(title: appBarTitle, showBackButton: showBackButton),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 72),
            Center(child: ColdIcon(glyph, size: 80, color: glyphColor)),
            const SizedBox(height: 32),
            Text(
              title,
              style: text.titleHero.copyWith(color: colors.textContent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: text.bodyLarge.copyWith(color: colors.textMuted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (children.isNotEmpty) ...[const SizedBox(height: 32), ...children],
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(child: bottom),
    );
  }
}
