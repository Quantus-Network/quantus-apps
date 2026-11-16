import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/components/window_header_row.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/wave_field.dart';
import 'package:quantus_desktop_wallet/utils/ascii_field.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// One boot line: [text] with [highlight] somewhere in it, coloured to say
/// whether it reports something done or something under way.
class _BootLine {
  const _BootLine(this.text, {this.highlight, this.isDone = true});

  final String text;
  final String? highlight;
  final bool isDone;
}

/// The website's loader, shown once before the first Welcome: terminal lines
/// appear one by one, then the wave field is revealed from its centre
/// outward. [onFinished] is called when it has run, or at a click or a key
/// press, which skip it.
class BootIntro extends ConsumerStatefulWidget {
  const BootIntro({super.key, required this.onFinished});

  final VoidCallback onFinished;

  /// The text that draws the revealed field.
  static const stageKey = Key('boot-intro-stage');

  @override
  ConsumerState<BootIntro> createState() => _BootIntroState();
}

class _BootIntroState extends ConsumerState<BootIntro> with SingleTickerProviderStateMixin {
  // The website's timing. Its loader has three more lines; the reveal follows
  // the prompt by the same 100 milliseconds here.
  static const int _lineEveryMs = 120;
  static const int _stepEveryMs = 50;
  static const int _steps = 10;
  static const int _holdMs = 250;
  static const int _stageFadeMs = 350;
  static const int _blinkMs = 900;

  // The size of the website's loader field.
  static const int _stageCols = 86;
  static const int _stageRows = 22;

  /// What the signature scheme is called; a name, so it is not translated.
  static const _signatureScheme = 'ML-DSA / DILITHIUM-5';

  late final AnimationController _clock;
  bool _finished = false;

  List<_BootLine> _lines(AppLocalizations l10n) => [
    _BootLine(l10n.desktopBootProtocol),
    _BootLine(l10n.desktopBootNistModule(l10n.desktopBootStatusOk), highlight: l10n.desktopBootStatusOk),
    _BootLine(l10n.desktopBootInitializing(_signatureScheme), highlight: _signatureScheme, isDone: false),
    _BootLine(l10n.desktopBootSignatureScheme(l10n.desktopBootStatusActive), highlight: l10n.desktopBootStatusActive),
    _BootLine(l10n.desktopBootZkEngine(l10n.desktopBootStatusReady), highlight: l10n.desktopBootStatusReady),
    _BootLine(
      l10n.desktopBootChladni(l10n.desktopBootStatusLoading),
      highlight: l10n.desktopBootStatusLoading,
      isDone: false,
    ),
  ];

  /// How many lines there are before the prompt. Fixed, so the timing does
  /// not wait for the language.
  static const int _lineCount = 6;
  static const int _promptAtMs = (_lineCount - 1) * _lineEveryMs + 40;
  static const int _revealAtMs = _promptAtMs + 100;
  static const int _totalMs = _revealAtMs + _steps * _stepEveryMs + _holdMs;

  @override
  void initState() {
    super.initState();
    _clock =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: _totalMs),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _finish();
          })
          ..forward();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _clock.dispose();
    super.dispose();
  }

  /// Any key skips the intro. The key is left for whoever else handles it,
  /// so a menu shortcut still does its work.
  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _finish();
    return false;
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  /// The wave mode of each step of the reveal, as on the website.
  static (int, int) _modeAt(double reveal) {
    if (reveal > 0.8) return (2, 4);
    if (reveal > 0.62) return (3, 2);
    if (reveal > 0.42) return (2, 3);
    if (reveal > 0.2) return (1, 2);
    return (2, 1);
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines(ref.watch(l10nProvider));
    assert(lines.length == _lineCount);
    final colors = context.colorsV3;
    final lineStyle = context.themeTextV3.dataAddress.copyWith(height: 1.9, color: colors.textContent.useOpacity(0.35));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: ColoredBox(
        color: colors.bgVoid,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final elapsedMs = (_clock.value * _totalMs).round();
            final sinceReveal = elapsedMs - _revealAtMs;
            final step = (sinceReveal ~/ _stepEveryMs).clamp(0, _steps);
            final reveal = step / _steps;
            final (m, n) = _modeAt(reveal);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const WindowHeaderRow(leadsTheWindow: true, children: []),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (index, line) in lines.indexed)
                        Opacity(
                          opacity: elapsedMs >= index * _lineEveryMs ? 1 : 0,
                          child: _lineText(line, lineStyle, colors),
                        ),
                      Opacity(
                        opacity: elapsedMs >= _promptAtMs ? 1 : 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('> ', style: lineStyle),
                            Opacity(
                              opacity: (elapsedMs - _promptAtMs) % _blinkMs < _blinkMs ~/ 2 ? 1 : 0,
                              child: ColoredBox(color: colors.accentFlare, child: const SizedBox(width: 6, height: 11)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: OverflowBox(
                      // Its own size, whatever the space: smaller sits in the middle,
                      // larger is cut off evenly on every side.
                      minWidth: 0,
                      minHeight: 0,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: ExcludeSemantics(
                        child: Text(
                          key: BootIntro.stageKey,
                          sinceReveal < 0
                              ? ''
                              : renderAsciiField(
                                  m: m,
                                  n: n,
                                  // The website's loader clock: 0.06 a step.
                                  t: step * 0.06,
                                  cols: _stageCols,
                                  rows: _stageRows,
                                  reveal: reveal,
                                ),
                          softWrap: false,
                          textScaler: TextScaler.noScaling,
                          style: asciiFieldStyle(context, height: 1.18, letterSpacing: 0.06).copyWith(
                            color: colors.accentFlare.useOpacity(0.5 * (sinceReveal / _stageFadeMs).clamp(0.0, 1.0)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lineText(_BootLine line, TextStyle style, AppColorsV3 colors) {
    final highlight = line.highlight;
    if (highlight == null) return Text(line.text, style: style);

    final start = line.text.indexOf(highlight);
    if (start < 0) throw StateError('The boot line "${line.text}" does not contain "$highlight"');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: line.text.substring(0, start)),
          TextSpan(
            text: highlight,
            style: TextStyle(color: line.isDone ? colors.semanticSage : colors.accentFlare),
          ),
          TextSpan(text: line.text.substring(start + highlight.length)),
        ],
      ),
    );
  }
}
