# desktop_qr_camera

Reads the computer's camera on Windows and Linux so that the desktop wallet can scan a QR code. macOS uses `mobile_scanner` instead.

## Where it came from

This is a trimmed and patched copy of [`flutter_lite_camera`](https://pub.dev/packages/flutter_lite_camera) 0.2.4 by Xiao Ling, under the MIT license in `LICENSE`. It is kept in this repository so that a package update can never change code that runs with camera access. Commit `95c72bd4`, the first in PR #789, is the package exactly as published, and the PR's later commits show every change made to it. They stay available from `refs/pull/789/head` even after a squash merge.

## What changed

- Removed: the phone, web and macOS code, device listing, resolution control, JPEG writing and its bundled encoder.
- Every frame's size, row length and byte count is checked before it is read (`native/yuy2.h`, `native/nv12.h`).
- Windows: reads NV12 as well as YUY2 and tries each size the camera offers, no crash when reading without an open camera, a failed capture can be restarted, a stalled camera cannot hang closing it, and Media Foundation is delay-loaded so the wallet still starts on Windows N.
- Linux: the format the driver really chose is checked, a partly failed open cleans up only what it opened, and metadata nodes and nodes without a readable format, such as an infrared camera, are skipped.
- No camera, permission denied, camera busy and an unsupported camera are reported as different errors.
- Frames carry brightness only, and each frame is handed over once.

## Testing

`flutter test` covers the Dart side. The frame conversion and both preview textures' buffers and lifetimes are tested natively, under the sanitizers:

```bash
c++ -std=c++14 -Wall -Wextra -Werror -fsanitize=address,undefined -fno-sanitize-recover=undefined \
  -I native test/native/yuy2_test.cpp -o /tmp/yuy2_test && /tmp/yuy2_test
c++ -std=c++14 -Wall -Wextra -Werror -fsanitize=address,undefined -fno-sanitize-recover=undefined \
  -I linux test/native/camera_texture_buffer_test.cpp \
  -o /tmp/camera_texture_buffer_test && /tmp/camera_texture_buffer_test
c++ -std=c++17 -Wall -Wextra -Wno-unused-parameter -Werror -pthread \
  -fsanitize=address,undefined -fno-sanitize-recover=undefined -I test/native/fake_flutter -I windows \
  test/native/texture_handler_test.cpp windows/texture_handler.cpp \
  -o /tmp/texture_handler_test && /tmp/texture_handler_test
c++ -std=c++14 -Wall -Wextra -Wno-unused-parameter -Werror -fsanitize=address,undefined -fno-sanitize-recover=undefined \
  -I native test/native/windows_format_test.cpp -o /tmp/windows_format_test && /tmp/windows_format_test
c++ -std=c++14 -Wall -Wextra -Werror -pthread -fsanitize=address,undefined -fno-sanitize-recover=undefined \
  -I test/native/fake_v4l2 -I native test/native/camera_linux_open_test.cpp \
  -o /tmp/camera_linux_open_test && /tmp/camera_linux_open_test
```

The Windows and Linux capture code needs a real camera, so it is only built by CI and tested by hand.
