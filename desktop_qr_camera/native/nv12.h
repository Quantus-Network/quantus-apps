#ifndef DESKTOP_QR_CAMERA_NV12_H_
#define DESKTOP_QR_CAMERA_NV12_H_

#include <cstddef>
#include <cstdint>

#include "yuy2.h"

namespace desktop_qr_camera {

// Converts an NV12 frame to RGBA for the preview and to brightness alone for
// the QR decoder. NV12 is a plane of brightness followed by a plane of U and V
// pairs, one pair for each two by two block of pixels, both with the same
// stride. As with YUY2, nothing a driver supplies is trusted: a frame that does
// not hold every pixel it claims is refused before anything is read or written.
inline bool ConvertNv12(const uint8_t* source, size_t available, size_t stride, uint32_t width, uint32_t height,
                        uint8_t* rgba, size_t rgba_size, uint8_t* luma, size_t luma_size) {
  if (source == nullptr || rgba == nullptr || luma == nullptr) return false;
  if (width == 0 || height == 0 || width > kMaxFrameSide || height > kMaxFrameSide) return false;
  if (width % 2 != 0 || height % 2 != 0) return false;

  const size_t columns = width;
  const size_t rows = height;
  const size_t stored_rows = rows + rows / 2;
  if (stride < columns || available < columns) return false;
  // The last row needs no padding after it. Dividing cannot overflow, as
  // multiplying a driver's stride could.
  if (stride > (available - columns) / (stored_rows - 1)) return false;
  if (rgba_size != columns * rows * 4 || luma_size != columns * rows) return false;

  for (size_t row = 0; row < rows; row++) {
    const uint8_t* brightness = source + row * stride;
    const uint8_t* color = source + (rows + row / 2) * stride;
    uint8_t* rgba_out = rgba + row * columns * 4;
    uint8_t* luma_out = luma + row * columns;
    for (size_t column = 0; column < columns; column++) {
      const size_t pair = column - column % 2;
      const int u = color[pair] - 128;
      const int v = color[pair + 1] - 128;
      WriteRgba(brightness[column], u, v, rgba_out + column * 4);
      luma_out[column] = brightness[column];
    }
  }
  return true;
}

}  // namespace desktop_qr_camera

#endif  // DESKTOP_QR_CAMERA_NV12_H_
