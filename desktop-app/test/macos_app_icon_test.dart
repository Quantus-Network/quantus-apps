import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _iconSet = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';

/// A PNG's width and height, read from its header.
(int, int) _pngSize(Uint8List bytes) {
  final header = ByteData.sublistView(bytes, 16, 24);
  return (header.getUint32(0), header.getUint32(4));
}

/// An image's pixels as RGBA bytes, and its width.
Future<(Uint8List, int)> _pixels(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  return (data!.buffer.asUint8List(), image.width);
}

void main() {
  // macOS 26 and later draw the app's icon from the Icon Composer file;
  // macOS 12 to 15 take the images of the asset catalog's icon set.
  test('every image the icon set names is there, at its pixel size', () {
    final contents = jsonDecode(File('$_iconSet/Contents.json').readAsStringSync()) as Map<String, dynamic>;
    final images = (contents['images'] as List).cast<Map<String, dynamic>>();
    expect(images, isNotEmpty);
    for (final image in images) {
      final points = int.parse((image['size'] as String).split('x').first);
      final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
      final file = File('$_iconSet/${image['filename']}');
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(_pngSize(file.readAsBytesSync()), (points * scale, points * scale), reason: file.path);
    }
  });

  group('the icon set', () {
    testWidgets('is the Quantus icon: its centre is the dark fill inside the Q', (tester) async {
      await tester.runAsync(() async {
        final (pixels, width) = await _pixels('$_iconSet/app_icon_1024.png');
        final centre = (512 * width + 512) * 4;
        expect(pixels[centre + 3], greaterThan(240), reason: 'opaque');
        for (var channel = 0; channel < 3; channel++) {
          expect(pixels[centre + channel], lessThan(40), reason: 'channel $channel is dark');
        }
      });
    });

    // Apple's grid for macOS 11 to 15 puts the rounded square at 824 of 1024
    // pixels, 100 from each edge; a square that fills the canvas looks a
    // quarter bigger than every other icon in the Dock.
    testWidgets('leaves Apple\'s margin around the rounded square', (tester) async {
      await tester.runAsync(() async {
        for (final size in [1024, 256]) {
          final (pixels, width) = await _pixels('$_iconSet/app_icon_$size.png');
          int alpha(int x, int y) => pixels[(y * width + x) * 4 + 3];
          final margin = (size * 100 / 1024).floor();
          final half = size ~/ 2;
          for (final (x, y) in [
            (half, margin ~/ 2),
            (half, size - 1 - margin ~/ 2),
            (margin ~/ 2, half),
            (size - 1 - margin ~/ 2, half),
          ]) {
            expect(alpha(x, y), 0, reason: '$size px: ($x, $y) is in the margin');
          }
          final inside = margin + (size * 12 / 1024).ceil();
          for (final (x, y) in [(half, inside), (inside, half)]) {
            expect(alpha(x, y), greaterThan(240), reason: '$size px: ($x, $y) is on the square');
          }
        }
      });
    });
  });

  test('the Icon Composer file is in the app\'s resources', () {
    expect(File('macos/Runner/AppIcon.icon/icon.json').existsSync(), isTrue);
    final project = File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    // The app's resources are the build phase with its asset catalog; the
    // test target has a resources phase of its own.
    final appResources = RegExp(
      r'/\* Resources \*/ = \{\s*isa = PBXResourcesBuildPhase;[^}]*\}',
    ).allMatches(project).map((match) => match[0]!).where((phase) => phase.contains('Assets.xcassets in Resources'));
    expect(appResources, hasLength(1));
    expect(appResources.single, contains('AppIcon.icon in Resources'));
    // Named as the icon set is, so that both answer to the app's icon name.
    expect(project, contains('ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'));
  });
}
