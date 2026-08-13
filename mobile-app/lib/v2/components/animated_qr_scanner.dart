import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';

/// Sequence metadata encoded in one frame of an animated QR payload.
class AnimatedQrSequence {
  final int index;
  final int total;

  const AnimatedQrSequence({required this.index, required this.total});
}

/// Scans and accumulates frames from an animated QR code.
///
/// Payload format and completion rules are injected, so this component is not
/// coupled to Keystone or UR encoding. A failed [onComplete] resets and restarts
/// the scanner after reporting the exception through [onError].
class AnimatedQrScanner extends StatefulWidget {
  final bool Function(String part) acceptsPart;
  final bool Function(List<String> parts) isComplete;
  final Future<void> Function(List<String> parts) onComplete;
  final FutureOr<void> Function(Object error)? onError;
  final AnimatedQrSequence? Function(String part)? sequenceForPart;
  final String appBarTitle;
  final String stepLabel;
  final String title;
  final String instruction;
  final String progressHeader;
  final String submittingLabel;
  final String Function(int scanned, int total) progressLabel;
  final String Function(int scanned) scanningLabel;
  final String? errorText;
  final Future<List<String>> Function()? debugPartsBuilder;
  final String debugActionLabel;

  const AnimatedQrScanner({
    super.key,
    required this.acceptsPart,
    required this.isComplete,
    required this.onComplete,
    required this.appBarTitle,
    required this.stepLabel,
    required this.title,
    required this.instruction,
    required this.progressHeader,
    required this.submittingLabel,
    required this.progressLabel,
    required this.scanningLabel,
    this.onError,
    this.sequenceForPart,
    this.errorText,
    this.debugPartsBuilder,
    this.debugActionLabel = 'DEBUG: Simulate scan',
  });

  @override
  State<AnimatedQrScanner> createState() => _AnimatedQrScannerState();
}

class _AnimatedQrScannerState extends State<AnimatedQrScanner> {
  // Unrestricted: the default DetectionSpeed.normal enforces a 250ms timeout
  // between detections, capping an animated QR at ~4 frames/second. Duplicate
  // deliveries are cheap — parts dedupe through the set below.
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    formats: const [BarcodeFormat.qrCode],
  );
  final Set<String> _parts = {};
  final Set<int> _seenSequenceIndexes = {};

  int? _expectedParts;
  bool _done = false;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || !widget.acceptsPart(code) || !_parts.add(code)) return;

    final sequence = widget.sequenceForPart?.call(code);
    if (sequence != null) {
      _seenSequenceIndexes.add(sequence.index);
      _expectedParts = sequence.total;
    }

    final parts = _parts.toList(growable: false);
    if (!widget.isComplete(parts)) {
      setState(() {});
      return;
    }

    unawaited(_complete(parts));
  }

  Future<void> _complete(List<String> parts) async {
    if (_done) return;
    setState(() {
      _done = true;
      _submitting = true;
    });
    try {
      await _controller.stop();
      await widget.onComplete(parts);
    } catch (error) {
      try {
        await widget.onError?.call(error);
      } finally {
        if (mounted) {
          setState(() {
            _done = false;
            _submitting = false;
            _parts.clear();
            _seenSequenceIndexes.clear();
            _expectedParts = null;
          });
          await _controller.start();
        }
      }
    }
  }

  Future<void> _simulateScan() async {
    final builder = widget.debugPartsBuilder;
    if (builder == null || _done) return;
    try {
      await _complete(await builder());
    } catch (error) {
      await widget.onError?.call(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final progress = _expectedParts == null ? null : (_seenSequenceIndexes.length / _expectedParts!).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: V2AppBar(title: widget.appBarTitle),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stepLabel,
                        style: text.detail?.copyWith(
                          fontFamily: AppTextTheme.fontFamilySecondary,
                          color: colors.accentOrange,
                          letterSpacing: 0.96,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.title, style: text.paragraph?.copyWith(color: colors.textPrimary, height: 1.0)),
                      const SizedBox(height: 8),
                      Text(widget.instruction, style: text.detail?.copyWith(color: colors.textSubtle, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _cameraView(colors)),
                ),
                _bottomSection(colors, text, progress),
              ],
            ),
            if (_submitting)
              Positioned.fill(
                child: ColoredBox(
                  color: colors.background.useOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: colors.accentOrange),
                        const SizedBox(height: 16),
                        Text(widget.submittingLabel, style: text.paragraph?.copyWith(color: colors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cameraView(AppColorsV2 colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.textLabel),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frame = (constraints.maxWidth - 96).clamp(160.0, 300.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Center(
                  child: SizedBox(width: frame, height: frame, child: const _ScanBrackets()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bottomSection(AppColorsV2 colors, AppTextTheme text, double? progress) {
    final progressText = progress != null
        ? widget.progressLabel(_seenSequenceIndexes.length, _expectedParts!)
        : (_parts.isNotEmpty ? widget.scanningLabel(_parts.length) : null);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 25, 24, 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.surfaceDeep, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.errorText != null)
            Text(widget.errorText!, style: text.detail?.copyWith(color: colors.textError))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.progressHeader,
                  style: text.detail?.copyWith(
                    fontFamily: AppTextTheme.fontFamilySecondary,
                    color: colors.textSubtle,
                    letterSpacing: 0.96,
                  ),
                ),
                if (progressText != null)
                  Text(
                    progressText,
                    style: text.detail?.copyWith(
                      fontFamily: AppTextTheme.fontFamilySecondary,
                      color: colors.textPrimary,
                      letterSpacing: 0.96,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: colors.progressStepPendingDot,
                color: colors.accentOrange,
              ),
            ),
          ],
          if (widget.debugPartsBuilder != null && !_submitting) ...[
            const SizedBox(height: 16),
            QuantusButton.simple(label: widget.debugActionLabel, onTap: _simulateScan, variant: ButtonVariant.danger),
          ],
        ],
      ),
    );
  }
}

/// White corner brackets marking the scan region.
class _ScanBrackets extends StatelessWidget {
  const _ScanBrackets();

  static const double _length = 28;
  static const double _thickness = 2;

  Widget _corner({required Color color, required Alignment alignment}) {
    final horizontal = alignment.x < 0 ? Alignment.centerLeft : Alignment.centerRight;
    return Align(
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment.x < 0 ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (alignment.y < 0) ...[
            _bar(color: color, vertical: true),
            Align(
              alignment: horizontal,
              child: _bar(color: color, vertical: false),
            ),
          ] else ...[
            Align(
              alignment: horizontal,
              child: _bar(color: color, vertical: false),
            ),
            _bar(color: color, vertical: true),
          ],
        ],
      ),
    );
  }

  Widget _bar({required Color color, required bool vertical}) {
    return Container(width: vertical ? _thickness : _length, height: vertical ? _length : _thickness, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.colors.textPrimary;
    return Stack(
      children: [
        _corner(color: color, alignment: Alignment.topLeft),
        _corner(color: color, alignment: Alignment.topRight),
        _corner(color: color, alignment: Alignment.bottomLeft),
        _corner(color: color, alignment: Alignment.bottomRight),
      ],
    );
  }
}
