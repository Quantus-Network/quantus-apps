import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A part of the window: a rounded, bordered box on the window's darker
/// ground, under a header line when it has a [title]. Panels stand [gap]
/// apart, and [gap] in from the window's edges.
///
/// While what it shows is being fetched again ([isBusy]) a light runs along
/// the hairline under its header. The panel the keys are in ([isFocused])
/// has a lighter border.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.fillsHeight = true,
    this.isBusy = false,
    this.isFocused = false,
  });

  /// The space between panels, and between a panel and the window's edge.
  static const double gap = 8;

  /// The height of a panel's header line, above its hairline.
  static const double headerHeight = 40;

  /// The space between the header's ends and what it holds.
  static const double headerPadding = 16;

  /// The light that runs under the header while the panel is busy.
  static const busyLineKey = Key('panel-busy-line');

  /// What the panel holds, named in its header line.
  final String? title;

  /// What sits at the header line's end.
  final Widget? trailing;

  final Widget child;

  /// Whether [child] fills the panel's height under the header. Else the
  /// panel is as tall as [child].
  final bool fillsHeight;

  final bool isBusy;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final title = this.title;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.smBorder,
        border: Border.all(color: isFocused ? colors.textContent.useOpacity(0.28) : colors.borderHairline),
      ),
      child: ClipRRect(
        borderRadius: context.radiusV3.smBorder,
        child: Column(
          mainAxisSize: fillsHeight ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              SizedBox(
                height: headerHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: headerPadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: context.themeTextV3.bodyEmphasis.copyWith(color: colors.textContent),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                ),
              ),
              if (isBusy) const _BusyLine(key: busyLineKey) else const MenuDivider(),
            ],
            if (fillsHeight) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

/// A short glacier light running along the hairline under a panel's header,
/// over and over. With the system asking for less motion it is lit along
/// the whole line and still.
class _BusyLine extends StatefulWidget {
  const _BusyLine({super.key});

  /// One run from the line's start to its end.
  static const run = Duration(milliseconds: 1500);

  /// How much of the line the light covers.
  static const double share = 0.3;

  @override
  State<_BusyLine> createState() => _BusyLineState();
}

class _BusyLineState extends State<_BusyLine> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: _BusyLine.run);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glacier = context.colorsV3.semanticGlacier;
    final isStill = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: 1,
      child: ColoredBox(
        color: isStill ? glacier.useOpacity(0.6) : context.colorsV3.borderHairline,
        child: isStill
            ? null
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final light = width * _BusyLine.share;
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final at = Curves.easeInOut.transform(_controller.value);
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned(
                            left: -light + (width + light) * at,
                            width: light,
                            top: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [glacier.useOpacity(0), glacier, glacier.useOpacity(0)],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
