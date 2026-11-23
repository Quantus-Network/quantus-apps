#ifndef DESKTOP_QR_CAMERA_YUY2_H_
#define DESKTOP_QR_CAMERA_YUY2_H_

#include <cstddef>
#include <cstdint>

namespace desktop_qr_camera {

// The longest side of a frame this package accepts. It keeps every size below
// well inside 64 bits, and a device claiming more is not a webcam.
constexpr uint32_t kMaxFrameSide = 4096;

inline uint8_t ClampToByte(int value) {
  if (value < 0) return 0;
  if (value > 255) return 255;
  return static_cast<uint8_t>(value);
}

// One pixel, from full-range BT.601 in 16.16 fixed point. u and v are centred
// on zero.
inline void WriteRgba(int y, int u, int v, uint8_t* rgba) {
  rgba[0] = ClampToByte(y + ((91881 * v) >> 16));
  rgba[1] = ClampToByte(y - ((22554 * u + 46802 * v) >> 16));
  rgba[2] = ClampToByte(y + ((116130 * u) >> 16));
  rgba[3] = 255;
}

// Converts a YUY2 frame to RGBA for the preview and to brightness alone for
// the QR decoder. A camera or driver supplies [source], [available] and
// [stride], so nothing about them is trusted: a frame that does not hold every
// pixel it claims is refused before anything is read or written. Returns
// whether the frame was converted.
inline bool ConvertYuy2(const uint8_t* source, size_t available, size_t stride, uint32_t width, uint32_t height,
                        uint8_t* rgba, size_t rgba_size, uint8_t* luma, size_t luma_size) {
  if (source == nullptr || rgba == nullptr || luma == nullptr) return false;
  if (width == 0 || height == 0 || width > kMaxFrameSide || height > kMaxFrameSide) return false;
  // YUY2 shares color between two pixels, so a row holds an even number.
  if (width % 2 != 0) return false;

  const size_t columns = width;
  const size_t rows = height;
  const size_t row_bytes = columns * 2;
  if (stride < row_bytes || available < row_bytes) return false;
  // The last row needs no padding after it. Dividing cannot overflow, as
  // multiplying a driver's stride could.
  if (rows > 1 && stride > (available - row_bytes) / (rows - 1)) return false;
  if (rgba_size != columns * rows * 4 || luma_size != columns * rows) return false;

  for (size_t row = 0; row < rows; row++) {
    const uint8_t* in = source + row * stride;
    uint8_t* rgba_out = rgba + row * columns * 4;
    uint8_t* luma_out = luma + row * columns;
    for (size_t column = 0; column < columns; column += 2) {
      const int y1 = in[column * 2];
      const int u = in[column * 2 + 1] - 128;
      const int y2 = in[column * 2 + 2];
      const int v = in[column * 2 + 3] - 128;
      WriteRgba(y1, u, v, rgba_out + column * 4);
      WriteRgba(y2, u, v, rgba_out + (column + 1) * 4);
      luma_out[column] = static_cast<uint8_t>(y1);
      luma_out[column + 1] = static_cast<uint8_t>(y2);
    }
  }
  return true;
}

}  // namespace desktop_qr_camera

#endif  // DESKTOP_QR_CAMERA_YUY2_H_
