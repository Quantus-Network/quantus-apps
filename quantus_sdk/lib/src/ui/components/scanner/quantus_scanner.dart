import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Strings the scanner shows; the SDK carries no localisation of its own.
class ScannerLabels {
  final String back;
  final String torch;
  final String gallery;
  final String cameraUnavailable;
  final String cameraPermissionDenied;
  final String retry;

  const ScannerLabels({
    required this.back,
    required this.torch,
    required this.gallery,
    required this.cameraUnavailable,
    required this.cameraPermissionDenied,
    required this.retry,
  });
}

/// The one scan screen (Figma 05 · Send): a full-bleed camera dimmed outside a
/// rounded window with flare brackets, Back on top, torch and the optional
/// gallery under the window. [caption] sits above the window and [footer] at
/// the bottom; the window shrinks and moves up to stay clear of both.
///
/// The preview covers a surface placeholder, so without a camera (simulator,
/// permission denied) the placeholder shows and everything else stays put.
class QuantusScanner extends StatefulWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture capture) onDetect;
  final ScannerLabels labels;
  final Widget? caption;
  final Widget? footer;

  /// Shows the Gallery control when set.
  final VoidCallback? onPickImage;
  final List<ScannerControl> actions;

  /// Covers the screen with a spinner and this text while set.
  final String? busyLabel;

  const QuantusScanner({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.labels,
    this.caption,
    this.footer,
    this.onPickImage,
    this.actions = const [],
    this.busyLabel,
  });

  @override
  State<QuantusScanner> createState() => _QuantusScannerState();
}

class _QuantusScannerState extends State<QuantusScanner> {
  /// The plugin drops the error from its state on the next torch or
  /// orientation event, so the last one is held here until the camera runs.
  MobileScannerException? _cameraError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_trackCameraError);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_trackCameraError);
    super.dispose();
  }

  void _trackCameraError() {
    // A device without a camera stays without one: starting it again only
    // reports that the session already exists.
    if (_cameraError?.errorCode == MobileScannerErrorCode.unsupported) return;
    final camera = widget.controller.value;
    final error = camera.isRunning ? null : camera.error ?? _cameraError;
    if (identical(error, _cameraError)) return;
    if (error != null) debugPrint('Camera unavailable (${error.errorCode.name}): ${error.errorDetails?.message}');
    setState(() => _cameraError = error);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final labels = widget.labels;
    final busyLabel = widget.busyLabel;
    final cameraError = _cameraError;

    return Scaffold(
      backgroundColor: colors.bgVoid,
      body: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: colors.bgSurface2),
            MobileScanner(
              controller: widget.controller,
              onDetect: widget.onDetect,
              placeholderBuilder: (_) => const SizedBox.shrink(),
              errorBuilder: (_, _) => const SizedBox.shrink(),
            ),
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: widget.controller,
              builder: (context, camera, _) => CustomMultiChildLayout(
                delegate: _ScannerLayout(),
                children: [
                  LayoutId(
                    id: _Slot.window,
                    child: CustomPaint(
                      painter: ScanFramePainter(
                        accent: colors.accentFlare,
                        scrim: colors.bgVoid.useOpacity(0.8),
                        radius: context.radiusV3.lg,
                      ),
                      child: cameraError == null || busyLabel != null ? null : _cameraNotice(context, cameraError),
                    ),
                  ),
                  LayoutId(
                    id: _Slot.top,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          spacing: 24,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.pop(context),
                              child: SizedBox(
                                height: AppBackButton.hitSize,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 12,
                                  children: [
                                    QuantusIcon(QuantusIcons.caretLeft, color: colors.textWhite),
                                    Text(labels.back, style: text.titleScreen.copyWith(color: colors.textWhite)),
                                  ],
                                ),
                              ),
                            ),
                            ?widget.caption,
                          ],
                        ),
                      ),
                    ),
                  ),
                  LayoutId(
                    id: _Slot.controls,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 32,
                      children: [
                        ScannerControl(
                          quantusIcon: QuantusIcons.flashlight,
                          label: labels.torch,
                          isActive: camera.torchState == TorchState.on,
                          onTap: widget.controller.toggleTorch,
                        ),
                        if (widget.onPickImage != null)
                          ScannerControl(
                            quantusIcon: QuantusIcons.imageSquare,
                            label: labels.gallery,
                            onTap: widget.onPickImage,
                          ),
                        ...widget.actions,
                      ],
                    ),
                  ),
                  LayoutId(
                    id: _Slot.bottom,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: widget.footer ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (busyLabel != null)
              ColoredBox(
                color: colors.bgVoid.useOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 16,
                    children: [
                      CircularProgressIndicator(color: colors.accentFlare),
                      Text(busyLabel, style: text.body.copyWith(color: colors.textContent)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// What the window says when the camera failed. A device with no camera at
  /// all gets the notice only: there is nothing to grant or retry.
  Widget _cameraNotice(BuildContext context, MobileScannerException error) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final labels = widget.labels;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          Text(
            labels.cameraUnavailable,
            style: text.bodyEmphasis.copyWith(color: colors.textContent),
            textAlign: TextAlign.center,
          ),
          if (error.errorCode == MobileScannerErrorCode.permissionDenied)
            Text(
              labels.cameraPermissionDenied,
              style: text.caption.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          if (error.errorCode != MobileScannerErrorCode.unsupported)
            QuantusButton.simple(
              label: labels.retry,
              variant: ButtonVariant.underline,
              width: null,
              padding: const EdgeInsets.symmetric(vertical: 12),
              onTap: widget.controller.start,
            ),
        ],
      ),
    );
  }
}

/// Round camera control with its label underneath (Figma 05 · Send, Torch and
/// Gallery). [isActive] inverts the circle, as the lit torch does in 10 · Send.
class ScannerControl extends StatelessWidget {
  /// One of [icon] (a font glyph) or [quantusIcon] (an SVG from the icon set).
  final IconData? icon;
  final QuantusIcons? quantusIcon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  const ScannerControl({
    super.key,
    this.icon,
    this.quantusIcon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  }) : assert((icon == null) != (quantusIcon == null));

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final foreground = isActive ? colors.textVoid : colors.textWhite;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? colors.textContent : colors.bgVoid,
              border: Border.all(color: colors.borderHairline),
            ),
            child: quantusIcon != null
                ? QuantusIcon(quantusIcon!, color: foreground)
                : Icon(icon, size: 20, color: foreground),
          ),
          Text(label, style: context.themeTextV3.bodyEmphasis.copyWith(color: colors.textWhite)),
        ],
      ),
    );
  }
}

enum _Slot { window, top, controls, bottom }

/// Centres the scan window on the screen as Figma does, then shrinks and lifts
/// it until the brackets and the controls clear the top and bottom overlays.
class _ScannerLayout extends MultiChildLayoutDelegate {
  static const double _maxWindow = 280;
  static const double _minWindow = 160;
  static const double _sideMargin = 55;
  static const double _controlsGap = 49;
  static const double _clearance = 24;

  @override
  void performLayout(Size size) {
    final band = BoxConstraints(minWidth: size.width, maxWidth: size.width, maxHeight: size.height);
    final top = layoutChild(_Slot.top, band);
    final bottom = layoutChild(_Slot.bottom, band);
    final controls = layoutChild(_Slot.controls, BoxConstraints.loose(size));

    final highest = top.height + _clearance;
    final below = _controlsGap + controls.height + _clearance + bottom.height;
    final side = math.max(
      _minWindow,
      math.min(_maxWindow, math.min(size.width - 2 * _sideMargin, size.height - highest - below)),
    );
    final windowTop = math.max(highest, math.min((size.height - side) / 2, size.height - below - side));

    layoutChild(_Slot.window, BoxConstraints.tight(Size.square(side)));
    positionChild(_Slot.top, Offset.zero);
    positionChild(_Slot.bottom, Offset(0, size.height - bottom.height));
    positionChild(_Slot.window, Offset((size.width - side) / 2, windowTop));
    positionChild(_Slot.controls, Offset((size.width - controls.width) / 2, windowTop + side + _controlsGap));
  }

  @override
  bool shouldRelayout(_ScannerLayout oldDelegate) => false;
}
