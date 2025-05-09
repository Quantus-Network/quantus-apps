import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _hasScanned = false; // Add flag to track if we've already scanned

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.white);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.white);
                }
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front, color: Colors.white);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear, color: Colors.white);
                }
              },
            ),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_hasScanned) return; // Skip if we've already scanned

              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _hasScanned = true; // Set flag before popping
                  print('Popping QR scanner with: ${barcode.rawValue}');
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // Overlay with a centered scanning area
          Container(
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF0CE6ED), width: 2),
              ),
            ),
            margin: const EdgeInsets.all(50),
          ),
          // Scanning hint text
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              'Position the QR code within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.useOpacity(0.8),
                fontSize: 16,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
