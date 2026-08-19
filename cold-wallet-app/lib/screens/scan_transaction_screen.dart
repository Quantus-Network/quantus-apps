import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';

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

  Widget _debugPayloadButtons(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    Widget button(String label, Uint8List Function() build) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.bgSurface2,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => _loadDebugPayload(build()),
          child: Text(label, style: text.caption.copyWith(color: colors.textContent)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('DEBUG PAYLOADS', style: text.caption.copyWith(color: colors.textMuted)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            button('Send', DebugPayloads.transfer),
            button('Msig approve', DebugPayloads.multisigApproveTransfer),
            button('Vote aye', DebugPayloads.governanceVoteAye),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _cameraError(BuildContext context, MobileScannerException error) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return ColoredBox(
      color: colors.bgVoid,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, color: colors.textMuted, size: 64),
              const SizedBox(height: 24),
              Text(
                'Camera unavailable',
                style: text.titleScreen.copyWith(color: colors.textContent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Grant camera access in Settings to scan the transaction QR (${error.errorCode.name}).',
                style: text.body.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
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
    final size = MediaQuery.of(context).size;
    final frame = (size.width - 96).clamp(220.0, 300.0);

    final progress = _expectedParts == null ? null : (_seenSeq.length / _expectedParts!).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: colors.bgVoid,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect, errorBuilder: _cameraError),
          Center(
            child: Container(
              width: frame,
              height: frame,
              decoration: BoxDecoration(
                border: Border.all(color: colors.accentFlare, width: 2),
                borderRadius: context.radiusV3.mdBorder,
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
                    icon: Icon(Icons.arrow_back, color: colors.textContent),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _controller.toggleTorch,
                    icon: Icon(Icons.flash_on, color: colors.textContent),
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
                  style: text.body.copyWith(color: _error != null ? colors.semanticEmber : colors.textContent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (progress != null) ...[
                  ClipRRect(
                    borderRadius: context.radiusV3.xsBorder,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.bgSurface2,
                      color: colors.accentFlare,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_seenSeq.length} / ${_expectedParts!} parts',
                    style: text.caption.copyWith(color: colors.textMuted),
                  ),
                ] else if (_parts.isNotEmpty)
                  Text('${_parts.length} parts scanned', style: text.caption.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
