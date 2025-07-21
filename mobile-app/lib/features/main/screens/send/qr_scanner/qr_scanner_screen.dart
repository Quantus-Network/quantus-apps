import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

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
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, child) {
              return IconButton(
                color: Colors.white,
                icon: Icon(switch (state.torchState) {
                  TorchState.off => Icons.flash_off,
                  TorchState.on => Icons.flash_on,
                  TorchState.auto => Icons.flash_auto,
                  TorchState.unavailable => Icons.flash_off,
                }),
                onPressed: () => controller.toggleTorch(),
              );
            },
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (context, state, child) {
              return IconButton(
                color: Colors.white,
                icon: Icon(switch (state.cameraDirection) {
                  CameraFacing.front => Icons.camera_front,
                  CameraFacing.back => Icons.camera_rear,
                  CameraFacing.external => Icons.camera,
                  CameraFacing.unknown => Icons.camera,
                }),
                onPressed: () => controller.switchCamera(),
              );
            },
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
