import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
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
  final MobileScannerController _controller = MobileScannerController();
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

  Widget _cameraError(BuildContext context, MobileScannerException error) {
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
                'Grant camera access in Settings to scan the transaction QR (${error.errorCode.name}).',
                style: const TextStyle(color: Colors.white70),
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
