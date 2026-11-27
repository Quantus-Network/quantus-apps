// Makes the app icon images for macOS 12 to 15 from a 1024 px render of
// macos/Runner/AppIcon.icon. macOS 26 and later draw the icon from the Icon
// Composer file itself.
//
// Icon Composer renders the rounded square edge to edge; Apple's grid for the
// older systems puts it at 824 of 1024 px, centred, so each image here is the
// render scaled to that and centred on a clear canvas.
//
// From desktop-app/, after changing AppIcon.icon:
//
//   ictool="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
//   "$ictool" macos/Runner/AppIcon.icon --export-image --output-file /tmp/app_icon_render.png \
//     --platform macOS --rendition Default --width 1024 --height 1024 --scale 1
//   swift tool/macos_app_icon.swift /tmp/app_icon_render.png
//
// test/macos_app_icon_test.dart checks the result.

import AppKit

let iconSet = "macos/Runner/Assets.xcassets/AppIcon.appiconset"
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let squareShare = 824.0 / 1024.0

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data((message + "\n").utf8))
  exit(1)
}

guard CommandLine.arguments.count == 2 else { fail("Usage: swift tool/macos_app_icon.swift <1024 px render>") }
guard let render = NSImage(contentsOfFile: CommandLine.arguments[1]),
  let renderRep = render.representations.first, renderRep.pixelsWide == 1024, renderRep.pixelsHigh == 1024
else { fail("The render must be a 1024 × 1024 px image.") }
guard FileManager.default.fileExists(atPath: iconSet) else { fail("Run this from desktop-app/.") }

for size in sizes {
  guard
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
      hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
  else { fail("Could not make a \(size) px canvas.") }
  rep.size = NSSize(width: size, height: size)
  NSGraphicsContext.saveGraphicsState()
  guard let context = NSGraphicsContext(bitmapImageRep: rep) else { fail("Could not draw at \(size) px.") }
  NSGraphicsContext.current = context
  context.imageInterpolation = .high
  let side = Double(size) * squareShare
  let origin = (Double(size) - side) / 2
  render.draw(
    in: NSRect(x: origin, y: origin, width: side, height: side), from: .zero, operation: .copy, fraction: 1)
  NSGraphicsContext.restoreGraphicsState()
  guard let png = rep.representation(using: .png, properties: [:]) else { fail("Could not encode \(size) px.") }
  let path = "\(iconSet)/app_icon_\(size).png"
  do { try png.write(to: URL(fileURLWithPath: path)) } catch { fail("Could not write \(path): \(error)") }
  print("Wrote \(path)")
}
