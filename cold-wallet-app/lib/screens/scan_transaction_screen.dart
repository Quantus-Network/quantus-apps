import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// Scans a (possibly multi-part / animated) UR QR code, accumulating parts
/// until [isCompleteUr] is satisfied, then decodes to the raw payload bytes
/// and hands them to the signing screen. Fails loudly on decode errors.
class ScanTransactionScreen extends StatefulWidget {
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
  final RegExp _seqPattern = RegExp(r'/(\d+)-(\d+)/');

  int? _expectedParts;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || !code.toLowerCase().startsWith('ur:')) return;
    if (!_parts.add(code)) return; // already seen this exact frame

    final match = _seqPattern.firstMatch(code);
    if (match != null) {
      _seenSeq.add(int.parse(match.group(1)!));
      _expectedParts = int.parse(match.group(2)!);
    }

    final parts = _parts.toList();
    if (!isCompleteUr(urParts: parts)) {
      setState(() {});
      return;
    }

    _done = true;
    try {
      final payload = decodeUr(urParts: parts);
      _controller.stop();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SignTransactionScreen(payload: payload)));
    } catch (e) {
      _done = false;
      setState(() => _error = 'Failed to decode QR: $e');
    }
  }

  /// Simulators have no camera, so debug builds can inject a payload directly and
  /// exercise the same review → sign path a scan would reach.
  void _loadDebugPayload(Uint8List payload) {
    _controller.stop();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SignTransactionScreen(payload: payload)));
  }

  /// One button per payload in [DebugPayloads.all], so every screen the signer
  /// can be shown is one tap away on a simulator.
  Widget _debugPayloadButtons(BuildContext context) {
    final text = context.themeText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('DEBUG PAYLOADS', style: text.detail?.copyWith(color: Colors.white38, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in DebugPayloads.all.entries)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _loadDebugPayload(entry.value()),
                child: Text(entry.key, style: text.detail?.copyWith(color: Colors.white)),
              ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
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
      debugPrint('Camera restart failed: $e');
      if (mounted) setState(() => _error = 'Camera restart failed: $e');
    }
  }

  Widget _cameraError(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final detail = error.errorDetails?.message;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Camera unavailable',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                denied
                    ? 'Grant camera access in Settings to scan the transaction QR.'
                    : 'The camera could not be started (${error.errorCode.name})'
                          '${detail == null ? '' : ': $detail'}.',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              QuantusButton.simple(label: 'Try again', width: null, onTap: _restartCamera),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final size = MediaQuery.of(context).size;
    final frame = (size.width - 96).clamp(220.0, 300.0);

    final progress = _expectedParts == null ? null : (_seenSeq.length / _expectedParts!).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect, errorBuilder: _cameraError),
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
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _controller.toggleTorch,
                    icon: const Icon(Icons.flash_on, color: Colors.white),
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
                if (kDebugMode) _debugPayloadButtons(context),
                Text(
                  _error ?? 'Scan the transaction QR from your hot wallet',
                  style: text.paragraph?.copyWith(color: _error != null ? colors.error : Colors.white),
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
                    '${_seenSeq.length} / ${_expectedParts!} parts',
                    style: text.detail?.copyWith(color: Colors.white70),
                  ),
                ] else if (_parts.isNotEmpty)
                  Text('${_parts.length} parts scanned', style: text.detail?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
