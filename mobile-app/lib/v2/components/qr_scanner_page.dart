import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/route_intent_providers.dart';
import 'package:wallet_core/providers/scanner_labels_provider.dart';

class QrScannerPage extends ConsumerStatefulWidget {
  final bool Function(String)? validator;
  const QrScannerPage({super.key, this.validator});

  @override
  ConsumerState<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends ConsumerState<QrScannerPage> {
  final _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _handleCode(code);
  }

  void _handleCode(String code) {
    if (_scanned) return;
    // External input is trollable: bound its length before it reaches any
    // parser. Everything scanned here is an address or a /pay link.
    if (code.length > maxDeepLinkLength) {
      quantusPrint('Ignoring over-long scanned code (${code.length} chars)');
      return;
    }
    if (widget.validator != null && !widget.validator!(code)) return;
    _scanned = true;
    Navigator.pop(context, code);
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    final capture = await _controller.analyzeImage(image.path);
    if (!mounted) return;
    if (capture != null) {
      _onDetect(capture);
    } else {
      final l10n = ref.read(l10nProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.componentQrScannerNoCode)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return QuantusScanner(
      controller: _controller,
      onDetect: _onDetect,
      labels: ref.watch(scannerLabelsProvider),
      onPickImage: _pickImage,
      actions: [
        if (kDebugMode)
          ScannerControl(
            icon: Icons.bug_report,
            label: 'Debug',
            onTap: () => _handleCode(AppConstants.debugTestAddress),
          ),
      ],
    );
  }
}
