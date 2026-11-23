// What the Linux preview texture hands to Flutter. It needs no camera or GTK, so
// it runs anywhere, under the sanitizers:
//
//   c++ -std=c++14 -Wall -Wextra -Werror -fsanitize=address,undefined \
//     -I linux test/native/camera_texture_buffer_test.cpp \
//     -o /tmp/camera_texture_buffer_test && /tmp/camera_texture_buffer_test
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

#include "camera_texture_buffer.h"

static int failures = 0;

#define CHECK(condition)                                          \
  do {                                                            \
    if (!(condition)) {                                           \
      std::printf("FAILED %s:%d: %s\n", __FILE__, __LINE__, #condition); \
      failures++;                                                 \
    }                                                             \
  } while (false)

namespace {

bool Shows(const PresentedFrame& frame, const std::vector<uint8_t>& rgba, uint32_t width, uint32_t height) {
  return frame.rgba != nullptr && frame.width == width && frame.height == height &&
         std::memcmp(frame.rgba, rgba.data(), rgba.size()) == 0;
}

// The engine dereferences a null error if the texture reports no pixels, so
// the first paint, which comes before the first camera frame, must get some.
void TestBeforeTheFirstFrameItPresentsOneOpaqueBlackPixel() {
  CameraTextureBuffer buffer;
  CHECK(Shows(buffer.Present(), {0, 0, 0, 255}, 1, 1));
}

void TestTheFirstFrameReplacesThePlaceholder() {
  CameraTextureBuffer buffer;
  buffer.Present();
  const std::vector<uint8_t> frame = {1, 2, 3, 4, 5, 6, 7, 8};
  buffer.Update(frame.data(), 2, 1);
  CHECK(Shows(buffer.Present(), frame, 2, 1));
}

void TestPresentedPixelsSurviveALaterFrame() {
  CameraTextureBuffer buffer;
  const std::vector<uint8_t> first = {1, 2, 3, 4};
  const std::vector<uint8_t> second = {9, 9, 9, 9, 8, 8, 8, 8};
  buffer.Update(first.data(), 1, 1);
  const PresentedFrame presented = buffer.Present();
  buffer.Update(second.data(), 2, 1);
  CHECK(Shows(presented, first, 1, 1));
}

void TestAFrameOfAnotherSizeIsPresentedWhole() {
  CameraTextureBuffer buffer;
  const std::vector<uint8_t> small = {1, 2, 3, 4};
  const std::vector<uint8_t> large = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};
  buffer.Update(small.data(), 1, 1);
  buffer.Present();
  buffer.Update(large.data(), 2, 2);
  CHECK(Shows(buffer.Present(), large, 2, 2));
}

}  // namespace

int main() {
  TestBeforeTheFirstFrameItPresentsOneOpaqueBlackPixel();
  TestTheFirstFrameReplacesThePlaceholder();
  TestPresentedPixelsSurviveALaterFrame();
  TestAFrameOfAnotherSizeIsPresentedWhole();
  if (failures > 0) {
    std::printf("%d check(s) failed\n", failures);
    return 1;
  }
  std::printf("All camera texture buffer checks passed\n");
  return 0;
}
