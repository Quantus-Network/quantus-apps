import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:quantus_desktop_wallet/utils/ascii_field.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The text style of an ASCII field: the monospace face at 12 points, with the
/// line height and letter spacing (as a part of the font size) given.
TextStyle asciiFieldStyle(BuildContext context, {required double height, required double letterSpacing}) {
  const fontSize = 12.0;
  return context.themeTextV3.dataAddress.copyWith(
    fontSize: fontSize,
    height: height,
    letterSpacing: fontSize * letterSpacing,
  );
}

/// The website's hero background: a Chladni figure drawn in characters across
/// all the space it is given, slowly breathing, and easing into [mode]
/// whenever that changes.
///
/// With [animate] false it shows the figure of [mode] and stands still.
class WaveField extends StatefulWidget {
  const WaveField({super.key, required this.mode, required this.animate});

  /// The wave mode (m, n) the field moves towards.
  final (int, int) mode;
  final bool animate;

  @override
  State<WaveField> createState() => _WaveFieldState();
}

class _WaveFieldState extends State<WaveField> with SingleTickerProviderStateMixin {
  // The website sizes its grid from a cell this big, then draws slightly
  // larger characters, so the field overflows the window a little on every
  // side and is cut off there.
  static const double _cellWidth = 11 * 0.62;
  static const double _cellHeight = 11 * 1.22;

  /// The website advances its clock by 0.01 a frame, at 60 frames a second.
  static const double _clockPerSecond = 0.6;

  /// Each frame the website moves the mode 2% of the way to its target.
  static const double _easingLeftPerFrame = 0.98;

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  /// The field's clock, and where it stood when the ticker last started.
  double _time = 0;
  double _timeAtStart = 0;
  late double _m = widget.mode.$1.toDouble();
  late double _n = widget.mode.$2.toDouble();

  @override
  void initState() {
    super.initState();
    if (widget.animate) _start();
  }

  void _start() {
    _lastTick = Duration.zero;
    _timeAtStart = _time;
    (_ticker ??= createTicker(_onTick)).start();
  }

  @override
  void didUpdateWidget(WaveField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _start();
    } else {
      _ticker?.stop();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final frames = (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond * 60;
    final eased = 1 - math.pow(_easingLeftPerFrame, frames);
    _lastTick = elapsed;
    setState(() {
      _time = _timeAtStart + elapsed.inMicroseconds / Duration.microsecondsPerSecond * _clockPerSecond;
      _m += (widget.mode.$1 - _m) * eased;
      _n += (widget.mode.$2 - _n) * eased;
    });
  }

  @override
  Widget build(BuildContext context) {
    final (m, n) = widget.animate ? (math.max(1, _m.round()), math.max(1, _n.round())) : widget.mode;
    final style = asciiFieldStyle(
      context,
      height: 1.22,
      letterSpacing: 0.05,
    ).copyWith(color: context.colorsV3.accentFlare.useOpacity(0.38));

    return RepaintBoundary(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final field = renderAsciiField(
              m: m,
              n: n,
              t: _time,
              cols: (constraints.maxWidth / _cellWidth).floor(),
              rows: (constraints.maxHeight / _cellHeight).floor(),
            );

            return ClipRect(
              child: OverflowBox(
                // Its own size, whatever the space: smaller sits in the middle,
                // larger is cut off evenly on every side.
                minWidth: 0,
                minHeight: 0,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Text(field, style: style, softWrap: false, textScaler: TextScaler.noScaling),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Darkens the middle of a [WaveField] so the text over it stays readable:
/// an ellipse that fades out towards the window's edges.
class WaveFieldScrim extends StatelessWidget {
  const WaveFieldScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ScrimPainter(context.colorsV3.bgVoid), size: Size.infinite);
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The website's `radial-gradient(ellipse 46% 34% at 50% 50%, ...)`: a
    // circle of radius 1, stretched to 46% of the width by 34% of the height.
    final shader = RadialGradient(
      colors: [color.useOpacity(0.7), color.useOpacity(0.7), color.useOpacity(0)],
      stops: const [0, 0.3, 0.78],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));

    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(size.width * 0.46, size.height * 0.34)
      ..drawCircle(Offset.zero, 1, Paint()..shader = shader)
      ..restore();
  }

  @override
  bool shouldRepaint(_ScrimPainter oldDelegate) => oldDelegate.color != color;
}
