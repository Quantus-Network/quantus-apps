import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/utils/print.dart';

/// The one widget that looks up checkphrases. Drop-in for [Text]: give it the
/// address and it resolves the phrase in the background, never changing height
/// while it does. A transparent stand-in phrase holds the line until the real
/// one arrives, with a small spinner over it once the lookup takes a while.
class CheckphraseText extends StatefulWidget {
  /// Replaces the service lookup in tests.
  @visibleForTesting
  static Future<String?> Function(String address)? resolveOverride;

  static const spinnerDelay = Duration(milliseconds: 200);
  static const unavailableText = 'Checkphrase unavailable';
  static const standIn = 'Harbor-Velvet-Signal-Mirror-Canyon';

  final String address;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  /// Maps what is drawn, e.g. the phrase to its initials.
  final String Function(String phrase)? transform;

  /// Hands out the resolved phrase for actions that need its text, like copy.
  final ValueChanged<String>? onResolved;

  const CheckphraseText(
    this.address, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.transform,
    this.onResolved,
  });

  @override
  State<CheckphraseText> createState() => _CheckphraseTextState();
}

class _CheckphraseTextState extends State<CheckphraseText> {
  String? _phrase;
  bool _failed = false;
  bool _showSpinner = false;
  Timer? _spinnerTimer;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CheckphraseText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) _resolve();
  }

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    super.dispose();
  }

  void _resolve() {
    final generation = ++_generation;
    final address = widget.address;
    final override = CheckphraseText.resolveOverride;
    _spinnerTimer?.cancel();
    _failed = false;
    _showSpinner = false;
    _phrase = override == null ? HumanReadableChecksumService().cachedHumanReadableName(address) : null;
    final cached = _phrase;
    if (cached != null) {
      scheduleMicrotask(() {
        if (mounted && _generation == generation) widget.onResolved?.call(cached);
      });
      return;
    }
    _spinnerTimer = Timer(CheckphraseText.spinnerDelay, () {
      if (mounted && _generation == generation) setState(() => _showSpinner = true);
    });
    final lookup = override ?? HumanReadableChecksumService().getHumanReadableName;
    lookup(address).then(
      (phrase) => _settle(generation, phrase),
      onError: (Object e, StackTrace s) {
        quantusPrint('Checkphrase lookup failed for $address: $e\n$s');
        _settle(generation, null);
      },
    );
  }

  void _settle(int generation, String? phrase) {
    if (!mounted || _generation != generation) return;
    _spinnerTimer?.cancel();
    setState(() {
      _showSpinner = false;
      if (phrase == null || phrase.isEmpty) {
        _failed = true;
      } else {
        _phrase = phrase;
      }
    });
    if (phrase != null && phrase.isNotEmpty) widget.onResolved?.call(phrase);
  }

  Text _text(String data, TextStyle style) => Text(
    data,
    style: style,
    textAlign: widget.textAlign,
    maxLines: widget.maxLines,
    overflow: widget.overflow,
    softWrap: widget.softWrap,
  );

  AlignmentGeometry get _alignment => switch (widget.textAlign) {
    TextAlign.center => Alignment.center,
    TextAlign.right => Alignment.centerRight,
    TextAlign.left => Alignment.centerLeft,
    TextAlign.end => AlignmentDirectional.centerEnd,
    _ => AlignmentDirectional.centerStart,
  };

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? context.themeTextV3.body.copyWith(color: context.colorsV3.semanticLilac);
    final draw = widget.transform ?? (String s) => s;
    final shown = _phrase ?? (_failed ? CheckphraseText.unavailableText : null);
    if (shown != null) return _text(draw(shown), style);

    final size = style.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    return Stack(
      alignment: _alignment,
      children: [
        ExcludeSemantics(child: _text(draw(CheckphraseText.standIn), style.copyWith(color: Colors.transparent))),
        if (_showSpinner) Loader(size: size, color: style.color),
      ],
    );
  }
}
