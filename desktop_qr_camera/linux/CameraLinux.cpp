#include "camera.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/videodev2.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>

#include <algorithm>
#include <cstring>
#include <string>
#include <utility>

#include "yuy2.h"

namespace desktop_qr_camera {

namespace {

constexpr uint32_t kWantedWidth = 1280;
constexpr uint32_t kWantedHeight = 720;
constexpr unsigned int kBufferCount = 4;
// Webcams often take every second node, the others carrying metadata.
constexpr int kDevicesToTry = 64;
constexpr int kPollMilliseconds = 200;

CameraStatus StatusOfErrno(int error) {
  switch (error) {
    case EACCES:
    case EPERM:
      return CameraStatus::kPermissionDenied;
    case EBUSY:
      return CameraStatus::kBusy;
    case ENOENT:
    case ENODEV:
    case ENXIO:
      return CameraStatus::kNoCamera;
    default:
      return CameraStatus::kFailed;
  }
}

// When no node works, the failure that tells the person the most is reported.
int WeightOf(CameraStatus status) {
  switch (status) {
    case CameraStatus::kBusy:
      return 4;
    case CameraStatus::kPermissionDenied:
      return 3;
    case CameraStatus::kFailed:
      return 2;
    case CameraStatus::kUnsupported:
      return 1;
    default:
      return 0;
  }
}

// An ioctl that a signal interrupted is retried, as V4L2 expects.
int Control(int fd, unsigned long request, void* argument) {
  int result;
  do {
    result = ioctl(fd, request, argument);
  } while (result == -1 && errno == EINTR);
  return result;
}

bool CapturesVideo(int fd) {
  struct v4l2_capability capability;
  std::memset(&capability, 0, sizeof(capability));
  if (Control(fd, VIDIOC_QUERYCAP, &capability) != 0) return false;
  // device_caps describes this node; capabilities the whole physical device,
  // which would also match a webcam's metadata node.
  const uint32_t caps =
      (capability.capabilities & V4L2_CAP_DEVICE_CAPS) ? capability.device_caps : capability.capabilities;
  return (caps & V4L2_CAP_VIDEO_CAPTURE) != 0 && (caps & V4L2_CAP_STREAMING) != 0;
}

}  // namespace

CameraStatus Camera::StatusOf(int error) {
  error_code_.store(static_cast<uint32_t>(error));
  return StatusOfErrno(error);
}

std::string Camera::ErrorDetail() const {
  const uint32_t code = error_code_.load();
  return code == 0 ? std::string() : "errno " + std::to_string(code);
}

CameraStatus Camera::Open() {
  Release();
  failure_.store(CameraStatus::kOk);
  error_code_.store(0);

  // A node that can't be used says why, unless a usable camera follows it. An
  // infrared camera, for one, is often listed before the main camera.
  CameraStatus blocked = CameraStatus::kNoCamera;
  uint32_t blocked_code = 0;
  const auto note_blocked = [&blocked, &blocked_code](CameraStatus status, uint32_t code) {
    if (WeightOf(status) > WeightOf(blocked)) {
      blocked = status;
      blocked_code = code;
    }
  };
  for (int i = 0; i < kDevicesToTry && fd_ < 0; i++) {
    const std::string path = "/dev/video" + std::to_string(i);
    const int fd = open(path.c_str(), O_RDWR | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) {
      const int error = errno;
      note_blocked(StatusOfErrno(error), static_cast<uint32_t>(error));
      continue;
    }
    if (!CapturesVideo(fd)) {
      close(fd);
      continue;
    }

    fd_ = fd;
    error_code_.store(0);
    const CameraStatus format_status = ChooseFormat();
    if (format_status != CameraStatus::kOk) {
      note_blocked(format_status, error_code_.load());
      close(fd_);
      fd_ = -1;
    }
  }
  if (fd_ < 0) {
    error_code_.store(blocked_code);
    return blocked;
  }

  CameraStatus status = MapBuffers();
  if (status == CameraStatus::kOk) {
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    if (Control(fd_, VIDIOC_STREAMON, &type) != 0) {
      status = StatusOf(errno);
    } else {
      capture_started_ = true;
    }
  }
  if (status == CameraStatus::kOk) {
    // A node tried on the way here may have been refused.
    error_code_.store(0);
  } else {
    Release();
  }
  return status;
}

CameraStatus Camera::ChooseFormat() {
  struct v4l2_format format;
  std::memset(&format, 0, sizeof(format));
  format.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  format.fmt.pix.width = kWantedWidth;
  format.fmt.pix.height = kWantedHeight;
  format.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
  format.fmt.pix.field = V4L2_FIELD_NONE;
  if (Control(fd_, VIDIOC_S_FMT, &format) != 0) {
    const int error = errno;
    error_code_.store(static_cast<uint32_t>(error));
    return error == EBUSY ? CameraStatus::kBusy : CameraStatus::kUnsupported;
  }

  // The driver answers with what it can do, which may be another format.
  const uint32_t width = format.fmt.pix.width;
  const uint32_t height = format.fmt.pix.height;
  if (format.fmt.pix.pixelformat != V4L2_PIX_FMT_YUYV) return CameraStatus::kUnsupported;
  if (width == 0 || height == 0 || width > kMaxFrameSide || height > kMaxFrameSide || width % 2 != 0) {
    return CameraStatus::kUnsupported;
  }
  const size_t row_bytes = static_cast<size_t>(width) * 2;
  const size_t stride = UsableStride(format.fmt.pix.bytesperline, row_bytes);
  if (stride == 0) return CameraStatus::kUnsupported;

  width_ = width;
  height_ = height;
  stride_ = stride;
  return CameraStatus::kOk;
}

CameraStatus Camera::MapBuffers() {
  struct v4l2_requestbuffers request;
  std::memset(&request, 0, sizeof(request));
  request.count = kBufferCount;
  request.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
  request.memory = V4L2_MEMORY_MMAP;
  if (Control(fd_, VIDIOC_REQBUFS, &request) != 0) return StatusOf(errno);
  if (request.count == 0) return CameraStatus::kUnsupported;

  buffers_.reserve(request.count);
  for (unsigned int i = 0; i < request.count; i++) {
    struct v4l2_buffer buffer;
    std::memset(&buffer, 0, sizeof(buffer));
    buffer.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buffer.memory = V4L2_MEMORY_MMAP;
    buffer.index = i;
    if (Control(fd_, VIDIOC_QUERYBUF, &buffer) != 0) return StatusOf(errno);

    void* start = mmap(nullptr, buffer.length, PROT_READ | PROT_WRITE, MAP_SHARED, fd_, buffer.m.offset);
    if (start == MAP_FAILED) return StatusOf(errno);
    // Only what was really mapped is listed, so only that is ever unmapped.
    buffers_.push_back({start, buffer.length});

    if (Control(fd_, VIDIOC_QBUF, &buffer) != 0) return StatusOf(errno);
  }
  return CameraStatus::kOk;
}

void Camera::UnmapBuffers() {
  for (const MappedBuffer& buffer : buffers_) munmap(buffer.start, buffer.length);
  buffers_.clear();
}

void Camera::Release() {
  streaming_.store(false);
  if (capture_thread_.joinable()) capture_thread_.join();
  frame_callback_ = nullptr;

  {
    std::lock_guard<std::mutex> lock(frame_mutex_);
    newest_luma_.clear();
  }

  if (fd_ >= 0) {
    if (capture_started_) {
      enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
      Control(fd_, VIDIOC_STREAMOFF, &type);
      capture_started_ = false;
    }
    UnmapBuffers();
    close(fd_);
    fd_ = -1;
  }
  width_ = 0;
  height_ = 0;
  stride_ = 0;
}

bool Camera::StartCaptureLoop(FrameCallback callback) {
  if (fd_ < 0 || !capture_started_ || streaming_.load()) return false;
  // A loop that ended on its own has left a thread to join.
  if (capture_thread_.joinable()) capture_thread_.join();

  frame_callback_ = std::move(callback);
  streaming_.store(true);
  capture_thread_ = std::thread(&Camera::CaptureLoop, this);
  return true;
}

void Camera::StoreLuma(const std::vector<uint8_t>& luma) {
  std::lock_guard<std::mutex> lock(frame_mutex_);
  newest_luma_ = luma;
}

void Camera::CaptureLoop() {
  const size_t pixels = static_cast<size_t>(width_) * height_;
  std::vector<uint8_t> rgba(pixels * 4);
  std::vector<uint8_t> luma(pixels);
  UnreadableFrames unreadable;

  while (streaming_.load()) {
    // A timeout keeps Release() responsive when the camera stalls.
    struct pollfd waiting;
    waiting.fd = fd_;
    waiting.events = POLLIN;
    waiting.revents = 0;
    const int ready = poll(&waiting, 1, kPollMilliseconds);
    if (ready < 0) {
      if (errno == EINTR) continue;
      error_code_.store(static_cast<uint32_t>(errno));
      failure_.store(CameraStatus::kStopped);
      break;
    }
    if (ready == 0) continue;
    if (waiting.revents & (POLLERR | POLLHUP | POLLNVAL)) {
      failure_.store(CameraStatus::kStopped);
      break;
    }
    if (!(waiting.revents & POLLIN)) continue;

    struct v4l2_buffer buffer;
    std::memset(&buffer, 0, sizeof(buffer));
    buffer.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
    buffer.memory = V4L2_MEMORY_MMAP;
    if (Control(fd_, VIDIOC_DQBUF, &buffer) != 0) {
      const int error = errno;
      if (error == EAGAIN) continue;
      if (streaming_.load()) {
        error_code_.store(static_cast<uint32_t>(error));
        failure_.store(CameraStatus::kStopped);
      }
      break;
    }
    if (buffer.index >= buffers_.size()) {
      failure_.store(CameraStatus::kStopped);
      break;
    }

    const MappedBuffer& mapped = buffers_[buffer.index];
    // Some drivers leave bytesused at zero; the mapping is then the limit.
    const size_t available = buffer.bytesused == 0 ? mapped.length : std::min<size_t>(buffer.bytesused, mapped.length);
    const bool converted = (buffer.flags & V4L2_BUF_FLAG_ERROR) == 0 &&
                           ConvertYuy2(static_cast<const uint8_t*>(mapped.start), available, stride_, width_, height_,
                                       rgba.data(), rgba.size(), luma.data(), luma.size());

    if (Control(fd_, VIDIOC_QBUF, &buffer) != 0) {
      const int error = errno;
      if (streaming_.load()) {
        error_code_.store(static_cast<uint32_t>(error));
        failure_.store(CameraStatus::kStopped);
      }
      break;
    }
    if (unreadable.Note(converted)) {
      if (streaming_.load()) failure_.store(CameraStatus::kUnsupported);
      break;
    }
    if (!converted) continue;

    StoreLuma(luma);
    if (frame_callback_) frame_callback_(rgba.data(), width_, height_);
  }

  streaming_.store(false);
}

LumaFrame Camera::CaptureFrame() {
  LumaFrame frame;
  const CameraStatus failure = failure_.load();
  if (failure != CameraStatus::kOk) {
    frame.status = failure;
    return frame;
  }
  if (!streaming_.load()) {
    frame.status = CameraStatus::kStopped;
    return frame;
  }
  frame.width = width_;
  frame.height = height_;
  std::lock_guard<std::mutex> lock(frame_mutex_);
  frame.luma.swap(newest_luma_);
  return frame;
}

}  // namespace desktop_qr_camera
