import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/desktop_camera_scanner.dart';

final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) => DesktopCameraScanner.list());
