import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

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
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final screen = MediaQuery.of(context).size;
    final frameSize = (screen.width - 112).clamp(220.0, 280.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          CustomPaint(
            size: Size(screen.width, screen.height),
            painter: _OverlayPainter(frameSize: frameSize, screenSize: screen),
          ),
          Center(child: _ScanFrame(size: frameSize)),
          Positioned(
            left: 0,
            right: 0,
            top: screen.height / 2 + frameSize / 2 + 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder<MobileScannerState>(
                  valueListenable: _controller,
                  builder: (_, state, _) {
                    final isOn = state.torchState == TorchState.on;
                    return _actionButton(
                      icon: isOn ? Icons.flash_on : Icons.flash_off,
                      onTap: _controller.toggleTorch,
                      colors: colors,
                    );
                  },
                ),
                const SizedBox(width: 8),
                _actionButton(icon: Icons.image_outlined, onTap: _pickImage, colors: colors),
                if (kDebugMode) ...[
                  const SizedBox(width: 8),
                  _actionButton(
                    icon: Icons.bug_report,
                    onTap: () => _handleCode(AppConstants.debugTestAddress),
                    colors: colors,
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 24,
            right: 24,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: V2AppBar(title: l10n.componentQrScannerTitle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required VoidCallback onTap, required AppColorsV2 colors}) {
    return QuantusIconButton.rounded(icon: icon, onTap: onTap, size: IconButtonSize.large);
  }
}

class _OverlayPainter extends CustomPainter {
  final double frameSize;
  final Size screenSize;

  _OverlayPainter({required this.frameSize, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize,
      height: frameSize,
    );
    final path = Path()
      ..addRect(rect)
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(16)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => frameSize != old.frameSize;
}

class _ScanFrame extends StatelessWidget {
  final double size;
  const _ScanFrame({required this.size});

  @override
  Widget build(BuildContext context) {
    final color = context.colors.accentOrange;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          _corner(top: true, left: true, color: color),
          _corner(top: true, left: false, color: color),
          _corner(top: false, left: true, color: color),
          _corner(top: false, left: false, color: color),
        ],
      ),
    );
  }

  Widget _corner({required bool top, required bool left, required Color color}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: SizedBox(
        width: 41,
        height: 41,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: top && left ? const Radius.circular(16) : Radius.zero,
              topRight: top && !left ? const Radius.circular(16) : Radius.zero,
              bottomLeft: !top && left ? const Radius.circular(16) : Radius.zero,
              bottomRight: !top && !left ? const Radius.circular(16) : Radius.zero,
            ),
            border: Border(
              top: top ? BorderSide(color: color, width: 1.6) : BorderSide.none,
              bottom: !top ? BorderSide(color: color, width: 1.6) : BorderSide.none,
              left: left ? BorderSide(color: color, width: 1.6) : BorderSide.none,
              right: !left ? BorderSide(color: color, width: 1.6) : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
