// Which /dev/video node the Linux camera opens. The system calls are replaced
// by a fake set of nodes, so it runs anywhere, under the sanitizers:
//
//   c++ -std=c++14 -Wall -Wextra -Werror -pthread -fsanitize=address,undefined \
//     -I test/native/fake_v4l2 -I native test/native/camera_linux_open_test.cpp \
//     -o /tmp/camera_linux_open_test && /tmp/camera_linux_open_test
#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <utility>

#include "camera.h"

namespace {

struct FakeNode {
  int open_error = 0;
  bool captures = true;
  uint32_t pixel_format = V4L2_PIX_FMT_YUYV;
  int set_format_error = 0;
};

const int kFirstFd = 100;

std::map<int, FakeNode> nodes;
std::set<int> open_fds;

int fake_open(const char* path, int) {
  const int index = std::atoi(path + std::strlen("/dev/video"));
  const auto node = nodes.find(index);
  if (node == nodes.end()) {
    errno = ENOENT;
    return -1;
  }
  if (node->second.open_error != 0) {
    errno = node->second.open_error;
    return -1;
  }
  open_fds.insert(kFirstFd + index);
  return kFirstFd + index;
}

int fake_close(int fd) {
  open_fds.erase(fd);
  return 0;
}

int fake_ioctl(int fd, unsigned long request, void* argument) {
  const FakeNode& node = nodes[fd - kFirstFd];
  switch (request) {
    case VIDIOC_QUERYCAP: {
      auto* capability = static_cast<struct v4l2_capability*>(argument);
      capability->capabilities = V4L2_CAP_DEVICE_CAPS;
      capability->device_caps = node.captures ? V4L2_CAP_VIDEO_CAPTURE | V4L2_CAP_STREAMING : 0;
      return 0;
    }
    case VIDIOC_S_FMT: {
      if (node.set_format_error != 0) {
        errno = node.set_format_error;
        return -1;
      }
      auto* format = static_cast<struct v4l2_format*>(argument);
      format->fmt.pix.pixelformat = node.pixel_format;
      format->fmt.pix.bytesperline = format->fmt.pix.width * 2;
      return 0;
    }
    case VIDIOC_REQBUFS:
      static_cast<struct v4l2_requestbuffers*>(argument)->count = 1;
      return 0;
    case VIDIOC_QUERYBUF:
      static_cast<struct v4l2_buffer*>(argument)->length = 64;
      return 0;
    default:
      return 0;
  }
}

void* fake_mmap(void*, size_t length, int, int, int, off_t) { return std::malloc(length); }

int fake_munmap(void* start, size_t) {
  std::free(start);
  return 0;
}

}  // namespace

#define open(...) fake_open(__VA_ARGS__)
#define close(...) fake_close(__VA_ARGS__)
#define ioctl(...) fake_ioctl(__VA_ARGS__)
#define mmap(...) fake_mmap(__VA_ARGS__)
#define munmap(...) fake_munmap(__VA_ARGS__)
#include "../../linux/CameraLinux.cpp"
#undef open
#undef close
#undef ioctl
#undef mmap
#undef munmap
#include "../../native/camera.cc"

using desktop_qr_camera::Camera;
using desktop_qr_camera::CameraStatus;

static int failures = 0;

#define CHECK(condition)                                          \
  do {                                                            \
    if (!(condition)) {                                           \
      std::printf("FAILED %s:%d: %s\n", __FILE__, __LINE__, #condition); \
      failures++;                                                 \
    }                                                             \
  } while (false)

namespace {

FakeNode InfraredNode() {
  FakeNode node;
  node.pixel_format = V4L2_PIX_FMT_GREY;
  return node;
}

FakeNode RefusingNode(int error) {
  FakeNode node;
  node.set_format_error = error;
  return node;
}

FakeNode MetadataNode() {
  FakeNode node;
  node.captures = false;
  return node;
}

FakeNode UnopenableNode(int error) {
  FakeNode node;
  node.open_error = error;
  return node;
}

bool OnlyNodeOpenIs(int index) { return open_fds == std::set<int>{kFirstFd + index}; }

void Reset(std::map<int, FakeNode> fake_nodes) {
  nodes = std::move(fake_nodes);
  open_fds.clear();
}

void TestAPlainCameraOpens() {
  Reset({{0, FakeNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kOk);
  CHECK(OnlyNodeOpenIs(0));
  CHECK(camera.ErrorDetail().empty());
}

void TestAnInfraredNodeListedFirstIsPassedOver() {
  Reset({{0, InfraredNode()}, {1, FakeNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kOk);
  CHECK(OnlyNodeOpenIs(1));
}

void TestANodeThatRefusesTheFormatIsPassedOver() {
  Reset({{0, RefusingNode(EINVAL)}, {1, FakeNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kOk);
  CHECK(OnlyNodeOpenIs(1));
  CHECK(camera.ErrorDetail().empty());
}

void TestABusyNodeIsPassedOverForAFreeCamera() {
  Reset({{0, RefusingNode(EBUSY)}, {1, FakeNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kOk);
  CHECK(OnlyNodeOpenIs(1));
}

void TestMetadataNodesAreSkippedAndClosed() {
  Reset({{0, MetadataNode()}, {1, FakeNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kOk);
  CHECK(OnlyNodeOpenIs(1));
}

void TestWithNoUsableNodeItIsUnsupportedAndNothingStaysOpen() {
  Reset({{0, InfraredNode()}, {1, InfraredNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kUnsupported);
  CHECK(open_fds.empty());
}

void TestABusyCameraIsNotHiddenByAnInfraredNodeAfterIt() {
  Reset({{0, RefusingNode(EBUSY)}, {1, InfraredNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kBusy);
  CHECK(open_fds.empty());
  CHECK(camera.ErrorDetail() == "errno " + std::to_string(EBUSY));
}

void TestABusyCameraIsNotHiddenByAnInfraredNodeBeforeIt() {
  Reset({{0, InfraredNode()}, {1, RefusingNode(EBUSY)}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kBusy);
  CHECK(open_fds.empty());
  CHECK(camera.ErrorDetail() == "errno " + std::to_string(EBUSY));
}

void TestADeniedNodeIsReportedOverAnInfraredOne() {
  Reset({{0, UnopenableNode(EACCES)}, {1, InfraredNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kPermissionDenied);
  CHECK(camera.ErrorDetail() == "errno " + std::to_string(EACCES));
}

void TestADeniedNodeDoesNotStopACameraAfterIt() {
  Reset({{0, UnopenableNode(EACCES)}, {1, FakeNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kOk);
  CHECK(OnlyNodeOpenIs(1));
  CHECK(camera.ErrorDetail().empty());
}

void TestNoNodesIsNoCamera() {
  Reset({});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kNoCamera);
  CHECK(open_fds.empty());
}

void TestReleasingClosesTheCamera() {
  Reset({{0, InfraredNode()}, {1, FakeNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kOk);
  camera.Release();
  CHECK(open_fds.empty());
}

void TestACameraThatIsNotOpenCannotCapture() {
  Reset({});
  Camera camera;
  CHECK(!camera.StartCaptureLoop([](const uint8_t*, uint32_t, uint32_t) {}));
  CHECK(camera.CaptureFrame().status == CameraStatus::kStopped);
}

void TestAnOpenCameraThatIsNotCapturingHasNoFrame() {
  Reset({{0, FakeNode()}});
  Camera camera;
  CHECK(camera.Open() == CameraStatus::kOk);
  const desktop_qr_camera::LumaFrame frame = camera.CaptureFrame();
  CHECK(frame.status == CameraStatus::kStopped);
  CHECK(frame.luma.empty());
}

}  // namespace

int main() {
  TestACameraThatIsNotOpenCannotCapture();
  TestAnOpenCameraThatIsNotCapturingHasNoFrame();
  TestAPlainCameraOpens();
  TestAnInfraredNodeListedFirstIsPassedOver();
  TestANodeThatRefusesTheFormatIsPassedOver();
  TestABusyNodeIsPassedOverForAFreeCamera();
  TestMetadataNodesAreSkippedAndClosed();
  TestWithNoUsableNodeItIsUnsupportedAndNothingStaysOpen();
  TestABusyCameraIsNotHiddenByAnInfraredNodeAfterIt();
  TestABusyCameraIsNotHiddenByAnInfraredNodeBeforeIt();
  TestADeniedNodeIsReportedOverAnInfraredOne();
  TestADeniedNodeDoesNotStopACameraAfterIt();
  TestNoNodesIsNoCamera();
  TestReleasingClosesTheCamera();
  if (failures > 0) {
    std::printf("%d check(s) failed\n", failures);
    return 1;
  }
  std::printf("All Linux camera open checks passed\n");
  return 0;
}
