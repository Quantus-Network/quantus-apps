#ifndef DESKTOP_QR_CAMERA_WINDOWS_STATUS_H_
#define DESKTOP_QR_CAMERA_WINDOWS_STATUS_H_

#include <cstdint>
#include <cstdio>
#include <string>

#include "camera.h"

namespace desktop_qr_camera {

// Windows error codes as plain numbers, so that telling them apart can be
// tested anywhere. CameraWindows.cpp checks each against the SDK when it builds.
constexpr uint32_t kErrorAccessDenied = 0x80070005;
constexpr uint32_t kErrorSharingViolation = 0x80070020;
constexpr uint32_t kErrorBusy = 0x800700AA;
constexpr uint32_t kErrorHardwareStartFailed = 0xC00D3704;
constexpr uint32_t kErrorRecordingPreempted = 0xC00D3EA3;

// The raw code as it is written in Microsoft's documentation.
inline std::string HresultText(uint32_t code) {
  char text[32];
  std::snprintf(text, sizeof(text), "HRESULT 0x%08X", static_cast<unsigned int>(code));
  return text;
}

inline CameraStatus StatusOfError(uint32_t code) {
  if (code == kErrorAccessDenied) return CameraStatus::kPermissionDenied;
  if (code == kErrorSharingViolation || code == kErrorBusy || code == kErrorHardwareStartFailed ||
      code == kErrorRecordingPreempted) {
    return CameraStatus::kBusy;
  }
  return CameraStatus::kFailed;
}

// The camera refused a format. Anything but a permission or busy error means
// only that this format can't be used.
inline CameraStatus StatusOfRejectedFormat(uint32_t code) {
  const CameraStatus status = StatusOfError(code);
  return status == CameraStatus::kFailed ? CameraStatus::kUnsupported : status;
}

// Reading a frame failed. Anything but a permission or busy error means the
// camera has stopped, as when it is unplugged.
inline CameraStatus StatusOfStreamError(uint32_t code) {
  const CameraStatus status = StatusOfError(code);
  return status == CameraStatus::kFailed ? CameraStatus::kStopped : status;
}

}  // namespace desktop_qr_camera

#endif  // DESKTOP_QR_CAMERA_WINDOWS_STATUS_H_
