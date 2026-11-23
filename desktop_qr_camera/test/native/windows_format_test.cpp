// Which sizes the Windows camera tries, how it reads NV12, and how it tells its
// errors apart. It needs no camera, so it runs anywhere, under the sanitizers:
//
//   c++ -std=c++14 -Wall -Wextra -Wno-unused-parameter -Werror \
//     -fsanitize=address,undefined -fno-sanitize-recover=undefined -I native test/native/windows_format_test.cpp \
//     -o /tmp/windows_format_test && /tmp/windows_format_test
#include <cstdint>
#include <cstdio>
#include <limits>
#include <vector>

#include "frame_sizes.h"
#include "nv12.h"
#include "windows_status.h"

using desktop_qr_camera::CameraStatus;
using desktop_qr_camera::ConvertNv12;
using desktop_qr_camera::FrameSize;
using desktop_qr_camera::HresultText;
using desktop_qr_camera::kErrorAccessDenied;
using desktop_qr_camera::kErrorBusy;
using desktop_qr_camera::kErrorHardwareStartFailed;
using desktop_qr_camera::kErrorRecordingPreempted;
using desktop_qr_camera::kErrorSharingViolation;
using desktop_qr_camera::kMaxFrameSide;
using desktop_qr_camera::SizesNearestWanted;
using desktop_qr_camera::StatusOfError;
using desktop_qr_camera::StatusOfRejectedFormat;
using desktop_qr_camera::StatusOfStreamError;
using desktop_qr_camera::WriteRgba;

static int failures = 0;

#define CHECK(condition)                                          \
  do {                                                            \
    if (!(condition)) {                                           \
      std::printf("FAILED %s:%d: %s\n", __FILE__, __LINE__, #condition); \
      failures++;                                                 \
    }                                                             \
  } while (false)

namespace {

const uint8_t kFill = 0xAB;

bool Same(const std::vector<FrameSize>& sizes, const std::vector<FrameSize>& expected) {
  if (sizes.size() != expected.size()) return false;
  for (size_t i = 0; i < sizes.size(); i++) {
    if (sizes[i].width != expected[i].width || sizes[i].height != expected[i].height) return false;
  }
  return true;
}

void TestSizesAreTriedNearest720pFirst() {
  CHECK(Same(SizesNearestWanted({{640, 480}, {1920, 1080}, {1280, 720}, {320, 240}}),
             {{1280, 720}, {640, 480}, {1920, 1080}, {320, 240}}));
}

void TestASizeOfferedInSeveralFormatsIsTriedOnce() {
  CHECK(Same(SizesNearestWanted({{1280, 720}, {640, 480}, {1280, 720}, {640, 480}}), {{1280, 720}, {640, 480}}));
}

void TestSizesThatCannotBeReadAreDropped() {
  CHECK(Same(SizesNearestWanted({{0, 480},
                                 {640, 0},
                                 {641, 480},
                                 {kMaxFrameSide + 2, 480},
                                 {640, kMaxFrameSide + 1},
                                 {640, 480}}),
             {{640, 480}}));
}

void TestEquallyNearSizesKeepTheCamerasOrder() {
  CHECK(Same(SizesNearestWanted({{1240, 720}, {1320, 720}, {1280, 680}}), {{1240, 720}, {1320, 720}, {1280, 680}}));
}

void TestNoUsableSizeGivesNone() { CHECK(SizesNearestWanted({{0, 0}, {641, 481}}).empty()); }

// A 2x2 frame: its four brightness values, then one U and V pair.
const std::vector<uint8_t> kTwoByTwo = {10, 20, 30, 40, 100, 200};

struct Output {
  Output(uint32_t width, uint32_t height)
      : rgba(static_cast<size_t>(width) * height * 4, kFill), luma(static_cast<size_t>(width) * height, kFill) {}

  bool untouched() const {
    for (uint8_t byte : rgba) {
      if (byte != kFill) return false;
    }
    for (uint8_t byte : luma) {
      if (byte != kFill) return false;
    }
    return true;
  }

  std::vector<uint8_t> rgba;
  std::vector<uint8_t> luma;
};

bool Convert(const std::vector<uint8_t>& source, size_t stride, uint32_t width, uint32_t height, Output* out) {
  return ConvertNv12(source.data(), source.size(), stride, width, height, out->rgba.data(), out->rgba.size(),
                     out->luma.data(), out->luma.size());
}

void TestBrightnessIsTheYPlane() {
  Output out(2, 2);
  CHECK(Convert(kTwoByTwo, 2, 2, 2, &out));
  CHECK((out.luma == std::vector<uint8_t>{10, 20, 30, 40}));
}

void TestColorComesFromTheSharedPairWithUFirst() {
  Output out(2, 2);
  CHECK(Convert(kTwoByTwo, 2, 2, 2, &out));
  const int y_values[] = {10, 20, 30, 40};
  for (size_t pixel = 0; pixel < 4; pixel++) {
    uint8_t expected[4];
    WriteRgba(y_values[pixel], 100 - 128, 200 - 128, expected);
    for (size_t channel = 0; channel < 4; channel++) {
      CHECK(out.rgba[pixel * 4 + channel] == expected[channel]);
    }
  }
}

void TestEachRowOfPixelsUsesItsOwnColorRow() {
  // 2x4: two rows of color, each shared by two rows of pixels.
  const std::vector<uint8_t> frame = {1, 2, 3, 4, 5, 6, 7, 8, 100, 110, 150, 160};
  Output out(2, 4);
  CHECK(Convert(frame, 2, 2, 4, &out));
  uint8_t top[4];
  uint8_t bottom[4];
  WriteRgba(3, 100 - 128, 110 - 128, top);
  WriteRgba(5, 150 - 128, 160 - 128, bottom);
  for (size_t channel = 0; channel < 4; channel++) {
    CHECK(out.rgba[2 * 4 + channel] == top[channel]);
    CHECK(out.rgba[4 * 4 + channel] == bottom[channel]);
  }
}

void TestRowPaddingIsSkipped() {
  const std::vector<uint8_t> frame = {10, 20, 0, 0, 30, 40, 0, 0, 100, 200};
  Output out(2, 2);
  CHECK(Convert(frame, 4, 2, 2, &out));
  CHECK((out.luma == std::vector<uint8_t>{10, 20, 30, 40}));
}

void TestTheLastRowNeedsNoPadding() {
  const std::vector<uint8_t> frame = {10, 20, 0, 0, 30, 40, 0, 0, 100, 200};
  Output out(2, 2);
  CHECK(frame.size() == 4 * 2 + 2);
  CHECK(Convert(frame, 4, 2, 2, &out));
}

void TestAFrameOneByteShortIsRefused() {
  const std::vector<uint8_t> frame(kTwoByTwo.begin(), kTwoByTwo.end() - 1);
  Output out(2, 2);
  CHECK(!Convert(frame, 2, 2, 2, &out));
  CHECK(out.untouched());
}

void TestOddSidesAreRefused() {
  const std::vector<uint8_t> frame(64, 0);
  Output odd_width(3, 2);
  CHECK(!Convert(frame, 4, 3, 2, &odd_width));
  Output odd_height(2, 3);
  CHECK(!Convert(frame, 4, 2, 3, &odd_height));
}

void TestAStrideThatCannotHoldARowIsRefused() {
  Output out(2, 2);
  CHECK(!Convert(kTwoByTwo, 1, 2, 2, &out));
  CHECK(out.untouched());
}

void TestAStrideThatWouldOverflowIsRefused() {
  Output out(2, 2);
  CHECK(!Convert(kTwoByTwo, (std::numeric_limits<size_t>::max)() / 2, 2, 2, &out));
  CHECK(out.untouched());
}

void TestOutputOfTheWrongSizeIsRefused() {
  Output out(2, 2);
  CHECK(!ConvertNv12(kTwoByTwo.data(), kTwoByTwo.size(), 2, 2, 2, out.rgba.data(), out.rgba.size() - 1,
                     out.luma.data(), out.luma.size()));
  CHECK(!ConvertNv12(kTwoByTwo.data(), kTwoByTwo.size(), 2, 2, 2, out.rgba.data(), out.rgba.size(), out.luma.data(),
                     out.luma.size() - 1));
  CHECK(out.untouched());
}

void TestNoSourceIsRefused() {
  Output out(2, 2);
  CHECK(!ConvertNv12(nullptr, 6, 2, 2, 2, out.rgba.data(), out.rgba.size(), out.luma.data(), out.luma.size()));
}

const uint32_t kBusyCodes[] = {kErrorSharingViolation, kErrorBusy, kErrorHardwareStartFailed, kErrorRecordingPreempted};
const uint32_t kDeviceInvalidated = 0xC00D3EA2;
const uint32_t kSomeOtherError = 0x80004005;

void TestEveryBusyCodeIsBusy() {
  for (uint32_t code : kBusyCodes) CHECK(StatusOfError(code) == CameraStatus::kBusy);
}

void TestAccessDeniedIsAPermissionProblem() {
  CHECK(StatusOfError(kErrorAccessDenied) == CameraStatus::kPermissionDenied);
}

void TestAnyOtherErrorIsAPlainFailure() { CHECK(StatusOfError(kSomeOtherError) == CameraStatus::kFailed); }

void TestARejectedFormatStaysBusyOrDenied() {
  for (uint32_t code : kBusyCodes) CHECK(StatusOfRejectedFormat(code) == CameraStatus::kBusy);
  CHECK(StatusOfRejectedFormat(kErrorAccessDenied) == CameraStatus::kPermissionDenied);
}

void TestAnyOtherRejectedFormatMeansTryTheNext() {
  CHECK(StatusOfRejectedFormat(kSomeOtherError) == CameraStatus::kUnsupported);
}

void TestAReadFailingBecauseAnotherAppHoldsTheCameraIsBusy() {
  for (uint32_t code : kBusyCodes) CHECK(StatusOfStreamError(code) == CameraStatus::kBusy);
  CHECK(StatusOfStreamError(kErrorAccessDenied) == CameraStatus::kPermissionDenied);
}

void TestAReadFailingBecauseTheCameraWentAwayIsStopped() {
  CHECK(StatusOfStreamError(kDeviceInvalidated) == CameraStatus::kStopped);
  CHECK(StatusOfStreamError(kSomeOtherError) == CameraStatus::kStopped);
}

void TestARawCodeIsWrittenAsMicrosoftWritesIt() {
  CHECK(HresultText(kErrorHardwareStartFailed) == "HRESULT 0xC00D3704");
  CHECK(HresultText(0x00000001) == "HRESULT 0x00000001");
}

}  // namespace

int main() {
  TestARawCodeIsWrittenAsMicrosoftWritesIt();
  TestEveryBusyCodeIsBusy();
  TestAccessDeniedIsAPermissionProblem();
  TestAnyOtherErrorIsAPlainFailure();
  TestARejectedFormatStaysBusyOrDenied();
  TestAnyOtherRejectedFormatMeansTryTheNext();
  TestAReadFailingBecauseAnotherAppHoldsTheCameraIsBusy();
  TestAReadFailingBecauseTheCameraWentAwayIsStopped();
  TestSizesAreTriedNearest720pFirst();
  TestASizeOfferedInSeveralFormatsIsTriedOnce();
  TestSizesThatCannotBeReadAreDropped();
  TestEquallyNearSizesKeepTheCamerasOrder();
  TestNoUsableSizeGivesNone();
  TestBrightnessIsTheYPlane();
  TestColorComesFromTheSharedPairWithUFirst();
  TestEachRowOfPixelsUsesItsOwnColorRow();
  TestRowPaddingIsSkipped();
  TestTheLastRowNeedsNoPadding();
  TestAFrameOneByteShortIsRefused();
  TestOddSidesAreRefused();
  TestAStrideThatCannotHoldARowIsRefused();
  TestAStrideThatWouldOverflowIsRefused();
  TestOutputOfTheWrongSizeIsRefused();
  TestNoSourceIsRefused();
  if (failures > 0) {
    std::printf("%d check(s) failed\n", failures);
    return 1;
  }
  std::printf("All Windows format checks passed\n");
  return 0;
}
