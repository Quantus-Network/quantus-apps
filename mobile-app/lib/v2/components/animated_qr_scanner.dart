import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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
  final FutureOr<void> Function(Object error, StackTrace stackTrace)? onError;
  final AnimatedQrSequence? Function(String part)? sequenceForPart;
  final String instruction;
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
    required this.instruction,
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
  final MobileScannerController _controller = MobileScannerController();
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
    } catch (error, stackTrace) {
      try {
        await widget.onError?.call(error, stackTrace);
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
    } catch (error, stackTrace) {
      await widget.onError?.call(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final size = MediaQuery.of(context).size;
    final frame = (size.width - 96).clamp(220.0, 300.0);
    final progress = _expectedParts == null ? null : (_seenSequenceIndexes.length / _expectedParts!).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: frame,
              height: frame,
              decoration: BoxDecoration(
                border: Border.all(color: colors.accentOrange, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  QuantusIconButton.rounded(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.pop(context),
                    style: IconButtonStyle.glass,
                  ),
                  const Spacer(),
                  QuantusIconButton.rounded(
                    icon: Icons.flash_on,
                    onTap: _controller.toggleTorch,
                    style: IconButtonStyle.glass,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.errorText ?? widget.instruction,
                  style: text.paragraph?.copyWith(color: widget.errorText != null ? colors.error : Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (progress != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.surface,
                      color: colors.accentOrange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.progressLabel(_seenSequenceIndexes.length, _expectedParts!),
                    style: text.detail?.copyWith(color: Colors.white70),
                  ),
                ] else if (_parts.isNotEmpty)
                  Text(widget.scanningLabel(_parts.length), style: text.detail?.copyWith(color: Colors.white70)),
                if (widget.debugPartsBuilder != null && !_submitting) ...[
                  const SizedBox(height: 16),
                  QuantusButton.simple(
                    label: widget.debugActionLabel,
                    onTap: _simulateScan,
                    variant: ButtonVariant.danger,
                    width: null,
                  ),
                ],
              ],
            ),
          ),
          if (_submitting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: colors.accentOrange),
                      const SizedBox(height: 16),
                      Text(widget.submittingLabel, style: text.paragraph?.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
