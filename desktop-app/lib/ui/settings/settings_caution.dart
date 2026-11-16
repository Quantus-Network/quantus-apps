import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// What a Settings step says before it does something that cannot be taken
/// back: a small warning line in capitals, a headline, and numbered lines.
class SettingsCaution extends StatelessWidget {
  const SettingsCaution({super.key, required this.eyebrow, required this.headline, required this.lines});

  final String eyebrow;
  final String headline;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final tint = colors.accentFlare;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, size: 13, color: tint),
            const SizedBox(width: 8),
            CapsText(eyebrow, style: text.dataAddress.copyWith(height: 1, letterSpacing: 2.4, color: tint)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          headline,
          style: text.titleHero.copyWith(fontSize: 26, height: 1.05, letterSpacing: -0.65, color: colors.textWhite),
        ),
        const SizedBox(height: 22),
        for (final (index, line) in lines.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: text.dataAddress.copyWith(height: 1.5, color: tint),
                  ),
                ),
                Expanded(
                  child: Text(line, style: text.body.copyWith(height: 1.5, color: colors.textContent)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The foot of a Settings step: what went wrong, if anything, then the
/// step's [buttons] at the bottom right, the default one last.
class SettingsStepFooter extends StatelessWidget {
  const SettingsStepFooter({super.key, required this.error, required this.buttons, this.leading = const []});

  final String? error;
  final List<Widget> buttons;

  /// Controls at the start of the row, such as a step's own actions.
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final error = this.error;

    return Row(
      children: [
        ...leading,
        Expanded(
          child: error == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: EdgeInsets.only(left: leading.isEmpty ? 0 : 12, right: 16),
                  child: Text(error, style: context.themeTextV3.body.copyWith(color: context.colorsV3.semanticEmber)),
                ),
        ),
        for (final (index, button) in buttons.indexed) ...[if (index > 0) const SizedBox(width: 10), button],
      ],
    );
  }
}
