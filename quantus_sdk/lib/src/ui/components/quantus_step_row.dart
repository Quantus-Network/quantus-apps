import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Tracking-timeline states for [QuantusStepRow].
///
/// Done settles, active is in flight, pending has not started, ended stopped.
enum StepRowState { done, active, pending, ended }

/// Figma Block / Step Row. Presentational only. Callers pass already-resolved [label] and [substate].
///
/// Takes the available width. Parent owns [state]; Active spins the flare mark.
class QuantusStepRow extends StatefulWidget {
  final StepRowState state;
  final String label;
  final String? substate;

  const QuantusStepRow({super.key, required this.state, required this.label, this.substate});

  @override
  State<QuantusStepRow> createState() => _QuantusStepRowState();
}

class _QuantusStepRowState extends State<QuantusStepRow> with SingleTickerProviderStateMixin {
  static const _spinDuration = Duration(seconds: 1);

  late final AnimationController _spin;

  bool get _isActive => widget.state == StepRowState.active;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: _spinDuration);
    if (_isActive) _spin.repeat();
  }

  @override
  void didUpdateWidget(QuantusStepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _StepStatusMark(state: widget.state, turns: _spin),
            const SizedBox(width: 14),
            Expanded(
              child: _StepCopy(state: widget.state, label: widget.label, substate: widget.substate),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepStatusMark extends StatelessWidget {
  static const _slot = 22.0;

  final StepRowState state;
  final Animation<double> turns;

  const _StepStatusMark({required this.state, required this.turns});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final mark = switch (state) {
      StepRowState.pending => _PendingDot(color: colors.bgSurface2),
      StepRowState.done => _Glyph(text: '✓', color: colors.semanticSage),
      StepRowState.active => RotationTransition(
        turns: turns,
        child: _Glyph(text: '◌', color: colors.accentFlare),
      ),
      StepRowState.ended => _Glyph(text: '⊘', color: colors.semanticSand),
    };

    return SizedBox(
      width: _slot,
      height: _slot,
      child: Center(child: mark),
    );
  }
}

class _Glyph extends StatelessWidget {
  final String text;
  final Color color;

  const _Glyph({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTextTheme.fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1,
        color: color,
      ),
    );
  }
}

class _PendingDot extends StatelessWidget {
  final Color color;

  const _PendingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StepCopy extends StatelessWidget {
  final StepRowState state;
  final String label;
  final String? substate;

  const _StepCopy({required this.state, required this.label, this.substate});

  bool get _showSubstate {
    return (state == StepRowState.active || state == StepRowState.ended) && (substate?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final emphasized = state == StepRowState.active || state == StepRowState.ended;
    final labelStyle = (emphasized ? text.bodyEmphasis : text.body).copyWith(
      color: emphasized ? colors.textContent : colors.textMuted2,
    );
    final substateText = substate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (_showSubstate && substateText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              substateText.toUpperCase(),
              style: _substateStyle(text, colors),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  /// Figma substate microlabel: Geist Mono Regular 10, tracking 0.8, from Label / Monogram.
  TextStyle _substateStyle(AppTextThemeV3 text, AppColorsV3 colors) {
    return text.labelMonogram.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.8,
      color: colors.textMuted2,
    );
  }
}
