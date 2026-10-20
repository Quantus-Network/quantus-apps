import 'dart:ui';

/// One decoded QR code in a camera frame: its text and its four corners in
/// the capture image's pixel space.
class QrDetection {
  final String raw;
  final List<Offset> corners;
  final Size imageSize;

  const QrDetection({required this.raw, required this.corners, required this.imageSize});
}
