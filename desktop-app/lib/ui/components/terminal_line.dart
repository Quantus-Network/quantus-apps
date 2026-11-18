import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One line of a terminal's report: `> NAME ....... [OK]`. The [status]
/// stands at the line's end, in sage unless given a [statusColor], with dot
/// leaders up to it; a line with none yet is its name alone, and a [isDim]
/// one is fainter, as a step not reached.
///
/// An [isBusy] line is at work: a spinner turns at its end, after the status
/// when it has one (`3/8 [/]`), so the line moves even while its status does
/// not. Where the system asks for less motion nothing turns: the status
/// stands alone, or [busyStill] when there is none.
///
/// The name is drawn in capitals, which is a look: a screen reader gets it
/// as it is written, and never the spinner.
class TerminalLine extends StatelessWidget {
  const TerminalLine({
    super.key,
    required this.name,
    this.status,
    this.statusColor,
    this.isDim = false,
    this.isBusy = false,
  });

  /// The spinner's faces, in the order it shows them.
  static const busyFaces = ['[|]', '[/]', '[-]', r'[\]'];

  /// How long the spinner shows one face.
  static const busyTurn = Duration(milliseconds: 120);

  /// What a busy line with no status says where nothing may turn.
  static const busyStill = '...';

  final String name;
  final String? status;
  final Color? statusColor;
  final bool isDim;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final isTurning = isBusy && !MediaQuery.disableAnimationsOf(context);
    final status = this.status ?? (isBusy && !isTurning ? busyStill : null);
    final style = context.themeTextV3.dataAddressLarge.copyWith(
      height: 1,
      letterSpacing: 0.6,
      color: isDim ? colors.textMuted2 : colors.textMuted,
    );
    final statusStyle = style.copyWith(color: statusColor ?? colors.semanticSage);

    return Semantics(
      label: this.status == null ? name : '$name ${this.status}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Text('> ${name.toUpperCase()}', style: style),
            const SizedBox(width: 8),
            Expanded(
              child: status == null && !isTurning
                  ? const SizedBox.shrink()
                  // Dot leaders up to the status, as many as fit.
                  : Text(
                      '.' * 200,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: style.copyWith(color: colors.textMuted2.useOpacity(0.5)),
                    ),
            ),
            if (status != null) ...[const SizedBox(width: 8), Text(status, style: statusStyle)],
            if (isTurning) ...[const SizedBox(width: 8), _Spinner(style: statusStyle)],
          ],
        ),
      ),
    );
  }
}

/// The spinner of a busy line: [TerminalLine.busyFaces] in turn, for as long
/// as it is on screen. Every face is as wide as the others, so nothing beside
/// it moves.
class _Spinner extends StatefulWidget {
  const _Spinner({required this.style});

  final TextStyle style;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: TerminalLine.busyTurn * TerminalLine.busyFaces.length,
  )..repeat();

  late final Animation<int> _face = StepTween(begin: 0, end: TerminalLine.busyFaces.length).animate(_clock);

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _face,
    builder: (context, _) => Text(TerminalLine.busyFaces[_face.value], style: widget.style),
  );
}
