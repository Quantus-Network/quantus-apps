#ifndef DESKTOP_QR_CAMERA_FRAME_SIZES_H_
#define DESKTOP_QR_CAMERA_FRAME_SIZES_H_

#include <algorithm>
#include <cstdint>
#include <vector>

#include "yuy2.h"

namespace desktop_qr_camera {

constexpr uint32_t kWantedWidth = 1280;
constexpr uint32_t kWantedHeight = 720;

struct FrameSize {
  uint32_t width;
  uint32_t height;
};

inline int64_t DistanceFromWanted(const FrameSize& size) {
  const int64_t across = static_cast<int64_t>(size.width) - static_cast<int64_t>(kWantedWidth);
  const int64_t down = static_cast<int64_t>(size.height) - static_cast<int64_t>(kWantedHeight);
  return (across < 0 ? -across : across) + (down < 0 ? -down : down);
}

// The sizes a camera offers that can be read, each once, nearest the wanted
// size first. Equally near sizes keep the camera's order.
inline std::vector<FrameSize> SizesNearestWanted(const std::vector<FrameSize>& offered) {
  std::vector<FrameSize> sizes;
  for (const FrameSize& size : offered) {
    if (!IsReadableFrameSize(size.width, size.height)) continue;
    const bool is_listed = std::any_of(sizes.begin(), sizes.end(), [&size](const FrameSize& other) {
      return other.width == size.width && other.height == size.height;
    });
    if (!is_listed) sizes.push_back(size);
  }
  std::stable_sort(sizes.begin(), sizes.end(), [](const FrameSize& a, const FrameSize& b) {
    return DistanceFromWanted(a) < DistanceFromWanted(b);
  });
  return sizes;
}

}  // namespace desktop_qr_camera

#endif  // DESKTOP_QR_CAMERA_FRAME_SIZES_H_
