import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final String asset;
  final GestureTapCallback? onTap;
  final bool filled;

  static const mediumAsset = 'assets/v2/glass_medium_clear.png';
  static const mediumSmallAsset = 'assets/v2/glass_medium_clear_small.png'; // 36px height
  static const smallAsset = 'assets/v2/glass_40.png';
  static const tinyAsset = 'assets/v2/glass_tiny_button.png';
  static const wideAsset = 'assets/v2/glass_wide_clear.png';
  static const wideClearAsset = 'assets/v2/glass_wide_clear.png';

  static const _inset = 42.0;
  static const _scale = 3.0;
  static const _slices = {
    mediumAsset: Rect.fromLTRB(_inset, _inset, 480 - _inset, 180 - _inset),
    mediumSmallAsset: Rect.fromLTRB(_inset, _inset, 288 - _inset, 108 - _inset),
    wideAsset: Rect.fromLTRB(_inset, _inset, 1026 - _inset, 168 - _inset),
  };

  double get defaultHeight => asset == smallAsset
      ? 40
      : asset == mediumSmallAsset
      ? 36
      : 56;

  double get defaultRadius => asset == tinyAsset
      ? 4
      : asset == smallAsset
      ? 8
      : 14;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    required this.asset,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final slice = _slices[asset];
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(defaultRadius),
        child: SizedBox(
          height: defaultHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: slice != null
                    ? _NineSliceImage(asset: asset, centerSlice: slice, scale: _scale)
                    : Image.asset(asset, fit: BoxFit.fill),
              ),
              if (filled) Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.1))),
              Positioned.fill(
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: Align(alignment: Alignment.center, child: child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NineSliceImage extends StatefulWidget {
  final String asset;
  final Rect centerSlice;
  final double scale;

  const _NineSliceImage({required this.asset, required this.centerSlice, required this.scale});

  @override
  State<_NineSliceImage> createState() => _NineSliceImageState();
}

class _NineSliceImageState extends State<_NineSliceImage> {
  ui.Image? _image;
  late final _listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => _image = info.image);
  });
  ImageStream? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = AssetImage(widget.asset).resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_image == null) return const SizedBox.shrink();
    return CustomPaint(painter: _NineSlicePainter(_image!, widget.centerSlice, widget.scale));
  }
}

class _NineSlicePainter extends CustomPainter {
  final ui.Image image;
  final Rect centerSlice;
  final double scale;

  _NineSlicePainter(this.image, this.centerSlice, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(1 / scale, 1 / scale);
    canvas.drawImageNine(
      image,
      centerSlice,
      Rect.fromLTWH(0, 0, size.width * scale, size.height * scale),
      Paint()..filterQuality = FilterQuality.low,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NineSlicePainter old) => image != old.image;
}
