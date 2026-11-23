# desktop_qr_camera

Reads the computer's camera on Windows and Linux so that the desktop wallet can scan a QR code. macOS uses `mobile_scanner` instead.

## Where it came from

This is a trimmed and patched copy of [`flutter_lite_camera`](https://pub.dev/packages/flutter_lite_camera) 0.2.4 by Xiao Ling, under the MIT license in `LICENSE`. It is kept in this repository so that a package update can never change code that runs with camera access. The first commit that added it is the package exactly as published, so `git log -p -- desktop_qr_camera` shows every change made since.

## What changed

- Removed: the phone, web and macOS code, device listing, resolution control, JPEG writing and its bundled encoder.
- Every frame's size, row length and byte count is checked before it is read (`native/yuy2.h`).
- Windows: no crash when reading without an open camera, a failed capture can be restarted, a stalled camera cannot hang closing it, and Media Foundation is delay-loaded so the wallet still starts on Windows N.
- Linux: the format the driver really chose is checked, a partly failed open cleans up only what it opened, and metadata nodes are skipped.
- No camera, permission denied, camera busy and an unsupported camera are reported as different errors.
- Frames carry brightness only, and each frame is handed over once.

## Testing

`flutter test` covers the Dart side. The frame conversion is tested natively, under the sanitizers:

```bash
c++ -std=c++14 -Wall -Wextra -Werror -fsanitize=address,undefined \
  -I native test/native/yuy2_test.cpp -o /tmp/yuy2_test && /tmp/yuy2_test
```

The Windows and Linux capture code needs a real camera, so it is only built by CI and tested by hand.
