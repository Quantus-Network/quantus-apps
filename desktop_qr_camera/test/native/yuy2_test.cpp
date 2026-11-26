// The conversion every camera frame goes through on Windows and Linux. It needs
// no camera, so it runs anywhere, under the sanitizers:
//
//   c++ -std=c++14 -Wall -Wextra -Werror -fsanitize=address,undefined -fno-sanitize-recover=undefined \
//     -I native test/native/yuy2_test.cpp -o /tmp/yuy2_test && /tmp/yuy2_test
#include <cstdint>
#include <cstdio>
#include <vector>

#include "yuy2.h"

using desktop_qr_camera::ConvertYuy2;
using desktop_qr_camera::IsReadableFrameSize;
using desktop_qr_camera::kMaxFrameSide;
using desktop_qr_camera::kMaxUnreadableFrames;
using desktop_qr_camera::UnreadableFrames;
using desktop_qr_camera::UsableStride;

static int failures = 0;

#define CHECK(condition)                                          \
  do {                                                            \
    if (!(condition)) {                                           \
      std::printf("FAILED %s:%d: %s\n", __FILE__, __LINE__, #condition); \
      failures++;                                                 \
    }                                                             \
  } while (false)

namespace {

const size_t kGuard = 16;
const uint8_t kFill = 0xAB;

// Output buffers for a frame, with a guard after each that must stay untouched.
struct Output {
  Output(uint32_t width, uint32_t height)
      : rgba(static_cast<size_t>(width) * height * 4 + kGuard, kFill),
        luma(static_cast<size_t>(width) * height + kGuard, kFill) {}

  size_t rgba_size() const { return rgba.size() - kGuard; }
  size_t luma_size() const { return luma.size() - kGuard; }

  bool untouched() const {
    for (uint8_t byte : rgba) {
      if (byte != kFill) return false;
    }
    for (uint8_t byte : luma) {
      if (byte != kFill) return false;
    }
    return true;
  }

  bool guards_intact() const {
    for (size_t i = rgba_size(); i < rgba.size(); i++) {
      if (rgba[i] != kFill) return false;
    }
    for (size_t i = luma_size(); i < luma.size(); i++) {
      if (luma[i] != kFill) return false;
    }
    return true;
  }

  std::vector<uint8_t> rgba;
  std::vector<uint8_t> luma;
};

bool Convert(const std::vector<uint8_t>& source, size_t stride, uint32_t width, uint32_t height, Output& out) {
  return ConvertYuy2(source.data(), source.size(), stride, width, height, out.rgba.data(), out.rgba_size(),
                     out.luma.data(), out.luma_size());
}

void ConvertsGrayPixels() {
  const std::vector<uint8_t> source = {10, 128, 200, 128, 30, 128, 40, 128};
  Output out(2, 2);
  CHECK(Convert(source, 4, 2, 2, out));
  CHECK((out.luma[0] == 10 && out.luma[1] == 200 && out.luma[2] == 30 && out.luma[3] == 40));
  CHECK((out.rgba[0] == 10 && out.rgba[1] == 10 && out.rgba[2] == 10 && out.rgba[3] == 255));
  CHECK((out.rgba[4] == 200 && out.rgba[5] == 200 && out.rgba[6] == 200 && out.rgba[7] == 255));
  CHECK((out.rgba[12] == 40 && out.rgba[15] == 255));
  CHECK(out.guards_intact());
}

void ConvertsColor() {
  // Pure red in full-range BT.601 is Y 76, U 85, V 255.
  const std::vector<uint8_t> source = {76, 85, 76, 255};
  Output out(2, 1);
  CHECK(Convert(source, 4, 2, 1, out));
  CHECK(out.rgba[0] >= 253);
  CHECK(out.rgba[1] <= 2);
  CHECK(out.rgba[2] <= 2);
  CHECK(out.guards_intact());
}

void ClampsToAByte() {
  const std::vector<uint8_t> bright = {255, 255, 255, 255};
  Output high(2, 1);
  CHECK(Convert(bright, 4, 2, 1, high));
  CHECK((high.rgba[0] == 255 && high.rgba[2] == 255));

  const std::vector<uint8_t> dark = {0, 0, 0, 0};
  Output low(2, 1);
  CHECK(Convert(dark, 4, 2, 1, low));
  CHECK((low.rgba[0] == 0 && low.rgba[2] == 0));
}

void FollowsARowPadding() {
  // Rows of 4 bytes of picture, then 2 of padding that must not be read as pixels.
  const std::vector<uint8_t> source = {1, 128, 2, 128, 99, 99, 3, 128, 4, 128};
  Output out(2, 2);
  CHECK(Convert(source, 6, 2, 2, out));
  CHECK((out.luma[0] == 1 && out.luma[1] == 2 && out.luma[2] == 3 && out.luma[3] == 4));
  CHECK(out.guards_intact());
}

void TheLastRowNeedsNoPadding() {
  const std::vector<uint8_t> source = {1, 128, 2, 128, 99, 99, 3, 128, 4};
  Output out(2, 2);
  CHECK(!Convert(source, 6, 2, 2, out));
  CHECK(out.untouched());
}

void RefusesAShortFrame() {
  const std::vector<uint8_t> source(7, 128);
  Output out(2, 2);
  CHECK(!Convert(source, 4, 2, 2, out));
  CHECK(out.untouched());
}

void RefusesAnEmptyFrame() {
  Output out(2, 2);
  CHECK(!ConvertYuy2(nullptr, 0, 4, 2, 2, out.rgba.data(), out.rgba_size(), out.luma.data(), out.luma_size()));
  CHECK(out.untouched());
}

void RefusesARowNarrowerThanItsPixels() {
  const std::vector<uint8_t> source(64, 128);
  Output out(2, 2);
  CHECK(!Convert(source, 3, 2, 2, out));
  CHECK(out.untouched());
}

void RefusesNoSize() {
  const std::vector<uint8_t> source(64, 128);
  Output out(2, 2);
  CHECK(!ConvertYuy2(source.data(), source.size(), 4, 0, 2, out.rgba.data(), 0, out.luma.data(), 0));
  CHECK(!ConvertYuy2(source.data(), source.size(), 4, 2, 0, out.rgba.data(), 0, out.luma.data(), 0));
  CHECK(out.untouched());
}

void RefusesAnOddWidth() {
  // YUY2 shares color between two pixels, so a row holds an even number.
  const std::vector<uint8_t> source(64, 128);
  Output out(3, 2);
  CHECK(!Convert(source, 6, 3, 2, out));
  CHECK(out.untouched());
}

void RefusesAnAbsurdSize() {
  const std::vector<uint8_t> source(64, 128);
  uint8_t rgba[16] = {};
  uint8_t luma[4] = {};
  CHECK(!ConvertYuy2(source.data(), source.size(), 8, kMaxFrameSide + 2, 2, rgba, sizeof rgba, luma, sizeof luma));
  CHECK(!ConvertYuy2(source.data(), source.size(), 8, 2, kMaxFrameSide + 1, rgba, sizeof rgba, luma, sizeof luma));
}

void RefusesSidesWhoseProductWraps() {
  // 65534 x 43692 x 3 wraps a 32-bit size, the bug in the original code.
  const std::vector<uint8_t> source(64, 128);
  uint8_t rgba[16] = {};
  uint8_t luma[4] = {};
  CHECK(!ConvertYuy2(source.data(), source.size(), 131068, 65534, 43692, rgba, sizeof rgba, luma, sizeof luma));
}

void RefusesOutputOfTheWrongSize() {
  const std::vector<uint8_t> source(16, 128);
  Output out(2, 2);
  CHECK(!ConvertYuy2(source.data(), source.size(), 4, 2, 2, out.rgba.data(), out.rgba_size() - 1, out.luma.data(),
                     out.luma_size()));
  CHECK(!ConvertYuy2(source.data(), source.size(), 4, 2, 2, out.rgba.data(), out.rgba_size(), out.luma.data(),
                     out.luma_size() - 1));
  CHECK(out.untouched());
}

void HandlesTheLargestFrame() {
  const uint32_t side = kMaxFrameSide;
  const std::vector<uint8_t> source(static_cast<size_t>(side) * side * 2, 128);
  Output out(side, side);
  CHECK(Convert(source, static_cast<size_t>(side) * 2, side, side, out));
  CHECK(out.guards_intact());
}

void TellsWhichFrameSizesCanBeRead() {
  CHECK(IsReadableFrameSize(2, 1));
  CHECK(IsReadableFrameSize(1280, 720));
  CHECK(IsReadableFrameSize(kMaxFrameSide, kMaxFrameSide));
  CHECK(!IsReadableFrameSize(0, 720));
  CHECK(!IsReadableFrameSize(1280, 0));
  CHECK(!IsReadableFrameSize(1281, 720));
  CHECK(!IsReadableFrameSize(kMaxFrameSide + 2, 720));
  CHECK(!IsReadableFrameSize(1280, kMaxFrameSide + 1));
}

void AStrideNotStatedIsThePlainRow() { CHECK(UsableStride(0, 1280) == 1280); }

void AStatedStrideIsUsedWhenItHoldsARow() {
  CHECK(UsableStride(1280, 1280) == 1280);
  CHECK(UsableStride(1344, 1280) == 1344);
}

void AStrideShorterThanARowIsRefused() { CHECK(UsableStride(1279, 1280) == 0); }

void ABackwardsStrideIsRefused() { CHECK(UsableStride(-1280, 1280) == 0); }

void AFewUnreadableFramesAreNotAFailure() {
  UnreadableFrames frames;
  for (int i = 0; i < kMaxUnreadableFrames - 1; i++) CHECK(!frames.Note(false));
}

void TooManyUnreadableFramesInARowAreAFailure() {
  UnreadableFrames frames;
  for (int i = 0; i < kMaxUnreadableFrames - 1; i++) frames.Note(false);
  CHECK(frames.Note(false));
}

void AGoodFrameStartsTheCountAgain() {
  UnreadableFrames frames;
  for (int i = 0; i < kMaxUnreadableFrames - 1; i++) frames.Note(false);
  CHECK(!frames.Note(true));
  for (int i = 0; i < kMaxUnreadableFrames - 1; i++) CHECK(!frames.Note(false));
}

}  // namespace

int main() {
  TellsWhichFrameSizesCanBeRead();
  AStrideNotStatedIsThePlainRow();
  AStatedStrideIsUsedWhenItHoldsARow();
  AStrideShorterThanARowIsRefused();
  ABackwardsStrideIsRefused();
  AFewUnreadableFramesAreNotAFailure();
  TooManyUnreadableFramesInARowAreAFailure();
  AGoodFrameStartsTheCountAgain();
  ConvertsGrayPixels();
  ConvertsColor();
  ClampsToAByte();
  FollowsARowPadding();
  TheLastRowNeedsNoPadding();
  RefusesAShortFrame();
  RefusesAnEmptyFrame();
  RefusesARowNarrowerThanItsPixels();
  RefusesNoSize();
  RefusesAnOddWidth();
  RefusesAnAbsurdSize();
  RefusesSidesWhoseProductWraps();
  RefusesOutputOfTheWrongSize();
  HandlesTheLargestFrame();
  if (failures > 0) {
    std::printf("%d checks failed\n", failures);
    return 1;
  }
  std::printf("all checks passed\n");
  return 0;
}
