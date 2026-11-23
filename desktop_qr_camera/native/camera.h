#ifndef DESKTOP_QR_CAMERA_CAMERA_H_
#define DESKTOP_QR_CAMERA_CAMERA_H_

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

#ifdef _WIN32
#include <windows.h>

#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <wrl/client.h>
#endif

namespace desktop_qr_camera {

// What happened, told apart so the app can say what to do about it.
enum class CameraStatus {
  kOk,
  kNoCamera,
  kPermissionDenied,
  kBusy,
  kUnsupported,
  kMediaUnavailable,
  kStopped,
  kFailed,
};

// The code the Dart side reads for a status. kOk has none.
inline const char* CameraStatusCode(CameraStatus status) {
  switch (status) {
    case CameraStatus::kOk:
      return "ok";
    case CameraStatus::kNoCamera:
      return "no_camera";
    case CameraStatus::kPermissionDenied:
      return "permission_denied";
    case CameraStatus::kBusy:
      return "busy";
    case CameraStatus::kUnsupported:
      return "unsupported";
    case CameraStatus::kMediaUnavailable:
      return "media_unavailable";
    case CameraStatus::kStopped:
      return "stopped";
    case CameraStatus::kFailed:
      return "failed";
  }
  return "failed";
}

// The newest frame's brightness. Empty when no new frame has arrived.
struct LumaFrame {
  CameraStatus status = CameraStatus::kOk;
  uint32_t width = 0;
  uint32_t height = 0;
  std::vector<uint8_t> luma;
};

// Called on the capture thread with an RGBA frame, valid only during the call.
typedef std::function<void(const uint8_t* rgba, uint32_t width, uint32_t height)> FrameCallback;

// The computer's first camera. Every method but the callback runs on the
// platform thread.
class Camera {
 public:
  Camera() = default;
  ~Camera() { Release(); }

  Camera(const Camera&) = delete;
  Camera& operator=(const Camera&) = delete;

  // Opens the first camera at the size nearest 1280x720. On failure nothing
  // stays open.
  CameraStatus Open();

  // Stops capturing and closes the camera, turning its light off. Safe to call
  // at any time.
  void Release();

  // Starts the capture thread. False when the camera is not open.
  bool StartCaptureLoop(FrameCallback callback);

  // Takes the newest frame, so that the next call returns a different one.
  LumaFrame CaptureFrame();

 private:
  void CaptureLoop();
  void StoreLuma(const std::vector<uint8_t>& luma);

  uint32_t width_ = 0;
  uint32_t height_ = 0;
  size_t stride_ = 0;

  std::thread capture_thread_;
  std::atomic<bool> streaming_{false};
  std::atomic<CameraStatus> failure_{CameraStatus::kOk};
  FrameCallback frame_callback_;
  std::mutex frame_mutex_;
  std::vector<uint8_t> newest_luma_;

#ifdef _WIN32
  CameraStatus OpenFirstDevice();
  CameraStatus ChooseFormat();

  Microsoft::WRL::ComPtr<IMFMediaSource> source_;
  Microsoft::WRL::ComPtr<IMFSourceReader> reader_;
  bool media_foundation_started_ = false;
#else
  struct MappedBuffer {
    void* start;
    size_t length;
  };

  CameraStatus ChooseFormat();
  CameraStatus MapBuffers();
  void UnmapBuffers();

  int fd_ = -1;
  std::vector<MappedBuffer> buffers_;
  bool capture_started_ = false;
#endif
};

}  // namespace desktop_qr_camera

#endif  // DESKTOP_QR_CAMERA_CAMERA_H_
