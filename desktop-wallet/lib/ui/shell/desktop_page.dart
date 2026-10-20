import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A tab's page: title row, then content in a centred column no wider than
/// [maxContentWidth], scrolling as a whole.
class DesktopPage extends StatelessWidget {
  static const double maxContentWidth = 1040;

  final String title;
  final List<Widget> actions;
  final Widget child;

  const DesktopPage({super.key, required this.title, required this.child, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 1400 ? 40.0 : 32.0;
        return Scrollbar(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: text.titleScreen.copyWith(color: colors.textContent)),
                        ),
                        ...actions,
                      ],
                    ),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
