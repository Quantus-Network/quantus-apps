import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// Balance over time as a stepped area, with a hover readout.
class BalanceChart extends ConsumerStatefulWidget {
  final List<BalanceHistoryPoint> points;
  final double height;

  const BalanceChart({super.key, required this.points, this.height = 220});

  @override
  ConsumerState<BalanceChart> createState() => _BalanceChartState();
}

class _BalanceChartState extends ConsumerState<BalanceChart> {
  Offset? _hover;

  @override
  Widget build(BuildContext context) {
    final hidden = ref.watch(isBalanceHiddenProvider);
    final formatter = ref.watch(numberFormattingServiceProvider);
    return SizedBox(
      height: widget.height,
      child: MouseRegion(
        onHover: (event) => setState(() => _hover = event.localPosition),
        onExit: (_) => setState(() => _hover = null),
        child: CustomPaint(
          painter: _BalanceChartPainter(
            points: widget.points,
            hover: _hover,
            hidden: hidden,
            colors: context.colorsV3,
            text: context.themeTextV3,
            format: (value) => formatter.formatBalance(value, smartDecimals: 2),
          ),
        ),
      ),
    );
  }
}

class _BalanceChartPainter extends CustomPainter {
  static const double leftGutter = 0;
  static const double rightGutter = 72;
  static const double bottomGutter = 24;

  final List<BalanceHistoryPoint> points;
  final Offset? hover;
  final bool hidden;
  final AppColorsV3 colors;
  final AppTextThemeV3 text;
  final String Function(BigInt) format;

  _BalanceChartPainter({
    required this.points,
    required this.hover,
    required this.hidden,
    required this.colors,
    required this.text,
    required this.format,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(leftGutter, 8, size.width - leftGutter - rightGutter, size.height - bottomGutter - 8);
    final grid = Paint()
      ..color = colors.borderHairline
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
    if (points.isEmpty) {
      canvas.drawLine(Offset(plot.left, plot.bottom), Offset(plot.right, plot.bottom), grid);
      return;
    }

    final minT = points.first.at.millisecondsSinceEpoch;
    final maxT = math.max(points.last.at.millisecondsSinceEpoch, minT + 1);
    var minB = points.first.balance;
    var maxB = points.first.balance;
    for (final p in points) {
      if (p.balance < minB) minB = p.balance;
      if (p.balance > maxB) maxB = p.balance;
    }
    if (maxB == minB) {
      final pad = maxB == BigInt.zero ? BigInt.from(10).pow(AppConstants.decimals) : maxB ~/ BigInt.from(10);
      maxB = maxB + pad;
      minB = minB - pad < BigInt.zero ? BigInt.zero : minB - pad;
    }
    final spanB = (maxB - minB).toDouble();
    double x(DateTime at) => plot.left + plot.width * (at.millisecondsSinceEpoch - minT) / (maxT - minT);
    double y(BigInt balance) => plot.bottom - plot.height * ((balance - minB).toDouble() / spanB);

    final line = Path()..moveTo(x(points.first.at), y(points.first.balance));
    for (var i = 1; i < points.length; i++) {
      line.lineTo(x(points[i].at), y(points[i - 1].balance));
      line.lineTo(x(points[i].at), y(points[i].balance));
    }
    final area = Path.from(line)
      ..lineTo(x(points.last.at), plot.bottom)
      ..lineTo(x(points.first.at), plot.bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.accentFlare.useOpacity(0.18), colors.accentFlare.useOpacity(0)],
        ).createShader(plot),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = colors.accentFlare
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    final last = Offset(x(points.last.at), y(points.last.balance));
    canvas.drawCircle(last, 8, Paint()..color = colors.accentFlare.useOpacity(0.25));
    canvas.drawCircle(last, 4, Paint()..color = colors.accentFlare);

    final labelStyle = text.caption.copyWith(
      color: colors.textMuted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (!hidden) {
      for (var i = 0; i <= 3; i++) {
        final value = minB + BigInt.from(((maxB - minB).toDouble() * (3 - i) / 3).round());
        _label(canvas, format(value), Offset(plot.right + 8, plot.top + plot.height * i / 3 - 7), labelStyle);
      }
    }
    final dateFormat = DateFormat.MMMd();
    for (var i = 0; i <= 3; i++) {
      final t = DateTime.fromMillisecondsSinceEpoch(minT + ((maxT - minT) * i / 3).round());
      final painter = _painter(dateFormat.format(t), labelStyle);
      final dx = (plot.left + plot.width * i / 3 - painter.width / 2).clamp(plot.left, plot.right - painter.width);
      painter.paint(canvas, Offset(dx, size.height - bottomGutter + 6));
    }

    final hover = this.hover;
    if (hover == null || !plot.inflate(8).contains(hover)) return;
    var nearest = points.first;
    for (final p in points) {
      if (x(p.at) <= hover.dx) nearest = p;
    }
    final hx = x(nearest.at);
    canvas.drawLine(
      Offset(hx, plot.top),
      Offset(hx, plot.bottom),
      Paint()
        ..color = colors.textMuted2
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(hx, y(nearest.balance)), 4, Paint()..color = colors.textContent);
    final tipDate = _painter(
      DateFormat.yMMMd().add_Hm().format(nearest.at),
      text.caption.copyWith(color: colors.textMuted),
    );
    final tipValue = _painter(
      hidden ? '••••' : '${format(nearest.balance)} ${AppConstants.tokenSymbol}',
      text.bodyEmphasis.copyWith(color: colors.textContent, fontFeatures: const [FontFeature.tabularFigures()]),
    );
    final tipWidth = math.max(tipDate.width, tipValue.width) + 24;
    final tipHeight = tipDate.height + tipValue.height + 20;
    final left = hx + 12 + tipWidth > plot.right ? hx - 12 - tipWidth : hx + 12;
    final top = (hover.dy - tipHeight / 2).clamp(plot.top, plot.bottom - tipHeight);
    final tipRect = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, tipWidth, tipHeight), const Radius.circular(8));
    canvas.drawRRect(tipRect, Paint()..color = colors.bgSurface2);
    canvas.drawRRect(
      tipRect,
      Paint()
        ..color = colors.borderHairline
        ..style = PaintingStyle.stroke,
    );
    tipDate.paint(canvas, Offset(left + 12, top + 10));
    tipValue.paint(canvas, Offset(left + 12, top + 10 + tipDate.height + 2));
  }

  TextPainter _painter(String value, TextStyle style) => TextPainter(
    text: TextSpan(text: value, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  void _label(Canvas canvas, String value, Offset at, TextStyle style) => _painter(value, style).paint(canvas, at);

  @override
  bool shouldRepaint(_BalanceChartPainter old) =>
      old.points != points || old.hover != hover || old.hidden != hidden || old.colors != colors;
}
