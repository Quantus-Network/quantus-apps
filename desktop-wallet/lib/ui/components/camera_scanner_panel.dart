import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/providers/settings_providers.dart';
import 'package:quantus_desktop_wallet/services/desktop_camera_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The webcam picture with the scanning overlay, or what to do when the
/// camera cannot be used.
class CameraScannerPanel extends ConsumerStatefulWidget {
  final QrPartCollector collector;
  final Future<void> Function(List<String> parts) onComplete;
  final FutureOr<void> Function(Object error)? onError;
  final QrScanStrings strings;
  final bool showFrameMap;
  final double aspectRatio;

  const CameraScannerPanel({
    super.key,
    required this.collector,
    required this.onComplete,
    required this.strings,
    this.onError,
    this.showFrameMap = true,
    this.aspectRatio = 16 / 9,
  });

  @override
  ConsumerState<CameraScannerPanel> createState() => _CameraScannerPanelState();
}

class _CameraScannerPanelState extends ConsumerState<CameraScannerPanel> {
  DesktopCameraScanner? _scanner;
  Object? _error;
  bool _noCamera = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _noCamera = false;
    });
    try {
      final cameras = await DesktopCameraScanner.list();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _noCamera = true);
        return;
      }
      final wanted = ref.read(selectedCameraNameProvider);
      final camera = cameras.firstWhere((c) => c.name == wanted, orElse: () => cameras.first);
      final scanner = DesktopCameraScanner(camera);
      await scanner.start();
      if (!mounted) {
        await scanner.dispose();
        return;
      }
      setState(() => _scanner = scanner);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    unawaited(_scanner?.dispose());
    super.dispose();
  }

  Future<void> _complete(List<String> parts) async {
    final scanner = _scanner;
    await scanner?.pause();
    try {
      await widget.onComplete(parts);
    } catch (e) {
      await scanner?.resume();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final scanner = _scanner;
    Widget body;
    if (_error != null || _noCamera) {
      body = _CameraProblem(error: _error, noCamera: _noCamera, onRetry: _start);
    } else if (scanner == null) {
      body = const Center(child: Loader(size: 24));
    } else {
      final previewSize = scanner.controller.value.previewSize;
      final preview = previewSize == null
          ? scanner.controller.buildPreview()
          : FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: scanner.controller.buildPreview(),
              ),
            );
      body = QrScanView(
        collector: widget.collector,
        detections: scanner.detections,
        preview: preview,
        onComplete: _complete,
        onError: widget.onError,
        strings: widget.strings,
        mirrored: scanner.mirrored,
        showFrameMap: widget.showFrameMap,
      );
    }
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgVoid,
          borderRadius: context.radiusV3.mdBorder,
          border: Border.all(color: colors.borderHairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}

class _CameraProblem extends ConsumerWidget {
  final Object? error;
  final bool noCamera;
  final Future<void> Function() onRetry;

  const _CameraProblem({required this.error, required this.noCamera, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final denied = error is CameraException && (error! as CameraException).code.toLowerCase().contains('access');
    final help = noCamera
        ? l10n.settingsCameraNone
        : denied
        ? (Platform.isMacOS
              ? l10n.cameraPermissionMac
              : Platform.isWindows
              ? l10n.cameraPermissionWindows
              : l10n.cameraPermissionLinux)
        : l10n.cameraError('$error');
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, size: 32, color: colors.textMuted),
            const SizedBox(height: 12),
            if (denied) Text(l10n.cameraPermissionTitle, style: text.headingRow.copyWith(color: colors.textContent)),
            const SizedBox(height: 8),
            Text(
              help,
              style: text.caption.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            QuantusButton.simple(label: l10n.commonTryAgain, variant: ButtonVariant.staged, width: 160, onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
