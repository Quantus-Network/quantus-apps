import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Reported through [AnimatedQrScanner.onError] when [maxUrScanParts] frames
/// arrive without completing a payload.
class UrScanLimitException implements Exception {
  const UrScanLimitException();

  @override
  String toString() => 'Scan did not complete within $maxUrScanParts frames';
}

/// Scans an animated UR QR code on [QuantusScanner], accumulating frames until
/// the payload is complete and showing how many have arrived.
///
/// A failed decode or [onComplete] is reported through [onError], then the
/// frames are dropped and scanning starts over.
class AnimatedQrScanner extends StatefulWidget {
  final Future<void> Function(Uint8List payload) onComplete;
  final FutureOr<void> Function(Object error) onError;

  /// Called for every new frame, so the caller can tell a stalled scan.
  final VoidCallback? onFrame;
  final ScannerLabels labels;
  final String progressLabel;
  final Widget? caption;

  /// Shown over the screen while [onComplete] runs.
  final String? busyLabel;
  final String? errorText;

  /// Stacked under the progress bar.
  final List<Widget> footerActions;
  final Future<List<String>> Function()? debugPartsBuilder;
  final String debugActionLabel;

  const AnimatedQrScanner({
    super.key,
    required this.onComplete,
    required this.onError,
    required this.labels,
    required this.progressLabel,
    this.onFrame,
    this.caption,
    this.busyLabel,
    this.errorText,
    this.footerActions = const [],
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _restart() {
    _parts.clear();
    _seenSequenceIndexes.clear();
    _expectedParts = null;
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null) _accept(code);
  }

  void _accept(String code) {
    if (_done || !isAcceptableUrPart(code)) return;
    // maxUrScanParts bounds the accumulation set: a hostile animation could
    // otherwise keep emitting distinct frames and grow memory without limit.
    // Reaching it means the set can never complete, so report it and start
    // over instead of dropping frames in silence.
    if (_parts.length >= maxUrScanParts) {
      unawaited(_abortOverflowing());
      return;
    }
    if (!_parts.add(code)) return;
    widget.onFrame?.call();

    final sequence = urSequenceFor(code);
    if (sequence != null) {
      _seenSequenceIndexes.add(sequence.index);
      _expectedParts = sequence.total;
    }

    final parts = _parts.toList(growable: false);
    if (!isCompleteUr(urParts: parts)) {
      setState(() {});
      return;
    }

    unawaited(_complete(parts));
  }

  Future<void> _abortOverflowing() async {
    debugPrint('Animated QR scan limit hit: $maxUrScanParts parts accumulated without completing');
    setState(_restart);
    await widget.onError(const UrScanLimitException());
  }

  Future<void> _complete(List<String> parts) async {
    if (_done) return;
    setState(() => _done = true);
    try {
      await _controller.stop();
      await widget.onComplete(decodeUr(urParts: parts));
    } catch (error) {
      try {
        await widget.onError(error);
      } finally {
        if (mounted) {
          setState(() {
            _done = false;
            _restart();
          });
          await _controller.start();
        }
      }
    }
  }

  /// Feeds the debug frames through the same path as the camera, paced so the
  /// progress can be watched.
  Future<void> _simulateScan() async {
    final List<String> parts;
    try {
      parts = await widget.debugPartsBuilder!();
    } catch (error) {
      await widget.onError(error);
      return;
    }
    for (final part in parts) {
      if (!mounted || _done) return;
      _accept(part);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorText = widget.errorText;

    return QuantusScanner(
      controller: _controller,
      onDetect: _onDetect,
      labels: widget.labels,
      caption: widget.caption,
      busyLabel: _done ? widget.busyLabel : null,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorText != null) ...[
            Text(errorText, style: context.themeTextV3.caption.copyWith(color: context.colorsV3.semanticEmber)),
            const SizedBox(height: 12),
          ],
          ScanProgress(label: widget.progressLabel, scanned: _seenSequenceIndexes.length, total: _expectedParts),
          if (widget.debugPartsBuilder != null && !_done) ...[
            const SizedBox(height: 16),
            QuantusButton.simple(label: widget.debugActionLabel, onTap: _simulateScan, variant: ButtonVariant.danger),
          ],
          ...widget.footerActions,
        ],
      ),
    );
  }
}
