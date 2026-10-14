import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/app_version.dart';
import 'package:quantus_cold_wallet/components/step_header.dart';
import 'package:quantus_cold_wallet/debug/debug_calls_screen.dart';
import 'package:quantus_cold_wallet/screens/sign_near_transaction_screen.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// Step 1 of signing (Figma Cold Wallet / Receiving, Stalled): scans a
/// (possibly multi-part / animated) UR QR code, accumulating parts until
/// [isCompleteUr] is satisfied, then decodes to the raw payload bytes and
/// hands them to the signing screen. Fails loudly on decode errors.
class ScanTransactionScreen extends StatefulWidget {
  /// How long without a new frame before the header swaps in the scanning
  /// tips. Scanning never stops: the frames already collected stay, the
  /// counter keeps going, and only the back button or Cancel leaves.
  static const stallTimeout = Duration(seconds: 3);

  const ScanTransactionScreen({super.key});

  @override
  State<ScanTransactionScreen> createState() => _ScanTransactionScreenState();
}

class _ScanTransactionScreenState extends State<ScanTransactionScreen> {
  // Unrestricted: the default DetectionSpeed.normal enforces a 250ms timeout
  // between detections, capping an animated QR at ~4 frames/second. Duplicate
  // deliveries are cheap — parts dedupe through the set below.
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    formats: const [BarcodeFormat.qrCode],
  );
  final Set<String> _parts = {};
  final Set<int> _seenSeq = {};

  int? _expectedParts;
  bool _done = false;
  String? _error;
  Timer? _stallTimer;
  bool _stalled = false;

  /// The last camera failure written to the log, so a rebuild of the same
  /// error state does not repeat it.
  String? _loggedCameraError;

  @override
  void dispose() {
    _stallTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Every new frame restarts the clock; when it runs out the header shows
  /// the tips. Armed only once a frame has arrived: with nothing received yet
  /// there is nothing to hint about.
  void _armStallTimer() {
    _stallTimer?.cancel();
    _stalled = false;
    _stallTimer = Timer(ScanTransactionScreen.stallTimeout, () {
      if (mounted && !_done) setState(() => _stalled = true);
    });
  }

  void _clearStall() {
    _stallTimer?.cancel();
    _stalled = false;
  }

  /// Drops the accumulated parts, reporting [reason] when there is one. A set
  /// that can't complete or decode never will, and keeping it makes every
  /// replayed frame look like a duplicate, so scanning has to start from empty.
  void _restartAccumulation(String? reason) {
    _parts.clear();
    _seenSeq.clear();
    _expectedParts = null;
    _clearStall();
    setState(() => _error = reason);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || !isAcceptableUrPart(code)) return;
    // maxUrScanParts bounds the accumulation set: a hostile animation could
    // otherwise keep emitting distinct frames and grow memory without limit.
    // Reaching it means the set can never complete, so say so and start over
    // instead of dropping frames in silence.
    if (_parts.length >= maxUrScanParts) {
      debugPrint('UR scan limit hit: $maxUrScanParts parts accumulated without completing');
      _restartAccumulation('Too many unusable QR frames. Restart the transfer on your hot wallet.');
      return;
    }
    if (!_parts.add(code)) return; // already seen this exact frame
    _armStallTimer();

    final sequence = urSequenceFor(code);
    if (sequence != null) {
      _seenSeq.add(sequence.index);
      _expectedParts = sequence.total;
    }

    final parts = _parts.toList();
    if (!isCompleteUr(urParts: parts)) {
      setState(() {});
      return;
    }

    _done = true;
    try {
      final screen = switch (AnySigningRequest.decode(decodeUr(urParts: parts))) {
        final SigningRequest request => SignTransactionScreen(request: request),
        final NearSigningRequest request => SignNearTransactionScreen(
          request: request,
          transaction: decodeNearTransaction(transaction: request.transaction),
        ),
      };
      _controller.stop();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
    } catch (e) {
      debugPrint('Rejected signing request QR: $e');
      // Keeping the parts would make every replayed frame a duplicate, so the
      // decode is never retried and the screen stays stuck on this error.
      _done = false;
      _restartAccumulation(switch (e) {
        UnsupportedSigningRequestVersionException() => '${e.message}. $updateAppHint $currentAppVersion',
        FormatException() => 'Not a Quantus signing request: ${e.message}',
        // decodeNearTransaction reports a malformed transaction as a bare string.
        String() => 'Could not read the NEAR transaction: $e',
        _ => 'Failed to decode QR: $e',
      });
    }
  }

  /// Simulators have no camera, so debug builds open the catalogue of every
  /// call the signer can review and inject one directly, exercising the same
  /// review → sign path a scan would reach.
  Future<void> _openDebugCalls() {
    // The controller is left running: MobileScanner starts and stops it with
    // this route's lifecycle, and starting it again here is what raised
    // controllerAlreadyInitialized on the way back.
    return Navigator.push(context, MaterialPageRoute(builder: (_) => const DebugCallsScreen()));
  }

  /// Retries a failed start. [MobileScannerController.start] folds scanner
  /// failures into the controller's value, re-rendering this same panel with
  /// the new reason; the controller-lifecycle errors it throws instead are
  /// surfaced through [_error], which each retry clears so a recovered camera
  /// never scans behind a stale failure banner.
  Future<void> _restartCamera() async {
    setState(() => _error = null);
    try {
      await _controller.start();
    } catch (e) {
      debugPrint('Camera could not be started: $e');
      if (mounted) setState(() => _error = 'The camera could not be started.');
    }
  }

  Widget _cameraError(BuildContext context, MobileScannerException error) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    if (_loggedCameraError != error.toString()) {
      _loggedCameraError = error.toString();
      debugPrint('Camera unavailable (${error.errorCode.name}): ${error.errorDetails?.message}');
    }

    return ColoredBox(
      color: colors.bgSurface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuantusIcon(QuantusIcons.warningCircle, size: 64, color: colors.textMuted),
              const SizedBox(height: 24),
              Text(
                'Camera unavailable',
                style: text.titleScreen.copyWith(color: colors.textContent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                denied
                    ? 'Grant camera access in Settings to scan the transaction QR.'
                    : 'The camera could not be started.',
                style: text.body.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              QuantusButton.simple(
                label: 'Try again',
                variant: ButtonVariant.secondary,
                padding: coldButtonPadding,
                onTap: _restartCamera,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final radius = context.radiusV3;
    final expected = _expectedParts;
    final progress = expected == null ? 0.0 : (_seenSeq.length / expected).clamp(0.0, 1.0);

    return ScaffoldBase(
      appBar: V2AppBar(
        title: 'Sign',
        trailing: QuantusButton.simple(
          label: 'Torch',
          variant: ButtonVariant.underline,
          width: null,
          padding: EdgeInsets.zero,
          onTap: _controller.toggleTorch,
        ),
      ),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepHeader(
            step: 1,
            total: 3,
            title: _stalled ? 'Not picking up new frames' : 'Scan the transaction',
            subtitle: _stalled
                ? "Move the two screens further apart, turn your phone's brightness up, and avoid glare."
                : "Hold this device over your phone's screen to load the transaction.",
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ClipRRect(
              borderRadius: radius.lgBorder,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(controller: _controller, onDetect: _onDetect, errorBuilder: _cameraError),
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, child) => state.error == null ? child! : const SizedBox.shrink(),
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: ScanFramePainter(accent: colors.accentFlare, scrim: colors.bgVoid.useOpacity(0.45)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(_error!, style: text.caption.copyWith(color: colors.semanticEmber)),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Text(
                  'RECEIVING TRANSACTION',
                  style: text.labelMonogram.copyWith(fontSize: 10, letterSpacing: 1, color: colors.textMuted),
                ),
                const Spacer(),
                if (expected != null)
                  Text('${_seenSeq.length}/$expected', style: text.dataAddress.copyWith(color: colors.textContent)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: radius.xsBorder,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: colors.bgSurface2,
                color: colors.accentFlare,
              ),
            ),
            const SizedBox(height: 20),
            QuantusButton.simple(
              label: 'Cancel Transaction',
              variant: ButtonVariant.underline,
              padding: const EdgeInsets.symmetric(vertical: 12),
              onTap: () => Navigator.pop(context),
            ),
            if (kDebugMode)
              QuantusButton.simple(
                label: 'Debug calls',
                variant: ButtonVariant.underline,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: _openDebugCalls,
              ),
          ],
        ),
      ),
    );
  }
}

/// Dims the preview outside a centred square and marks its four corners with
/// rounded L brackets in the accent colour, as the Figma scanner frame does.
class ScanFramePainter extends CustomPainter {
  final Color accent;
  final Color scrim;

  const ScanFramePainter({required this.accent, required this.scrim});

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.8;
    final frame = Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side);
    const cornerRadius = 12.0;
    final arm = side * 0.16;

    final window = Path()..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(cornerRadius)));
    final outside = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), window);
    canvas.drawPath(outside, Paint()..color = scrim);

    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final (corner, dx, dy) in [
      (frame.topLeft, 1.0, 1.0),
      (frame.topRight, -1.0, 1.0),
      (frame.bottomLeft, 1.0, -1.0),
      (frame.bottomRight, -1.0, -1.0),
    ]) {
      final bracket = Path()
        ..moveTo(corner.dx + dx * arm, corner.dy)
        ..lineTo(corner.dx + dx * cornerRadius, corner.dy)
        ..quadraticBezierTo(corner.dx, corner.dy, corner.dx, corner.dy + dy * cornerRadius)
        ..lineTo(corner.dx, corner.dy + dy * arm);
      canvas.drawPath(bracket, stroke);
    }
  }

  @override
  bool shouldRepaint(ScanFramePainter oldDelegate) => oldDelegate.accent != accent || oldDelegate.scrim != scrim;
}
