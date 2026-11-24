// The parts of Camera that are the same on Windows and Linux.
#include "camera.h"

#include <utility>

namespace desktop_qr_camera {

bool Camera::StartCaptureLoop(FrameCallback callback) {
  if (!IsOpen() || streaming_.load()) return false;
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
