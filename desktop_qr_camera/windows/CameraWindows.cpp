#include "camera.h"

#include <mferror.h>

#include <cstdint>
#include <initializer_list>
#include <vector>

#include "frame_sizes.h"
#include "nv12.h"
#include "windows_status.h"
#include "yuy2.h"

using Microsoft::WRL::ComPtr;

namespace desktop_qr_camera {

namespace {

constexpr DWORD kVideoStream = static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM);

static_assert(kErrorAccessDenied == static_cast<uint32_t>(E_ACCESSDENIED), "E_ACCESSDENIED");
static_assert(kErrorSharingViolation == (0x80070000u | ERROR_SHARING_VIOLATION), "ERROR_SHARING_VIOLATION");
static_assert(kErrorBusy == (0x80070000u | ERROR_BUSY), "ERROR_BUSY");
static_assert(kErrorHardwareStartFailed == static_cast<uint32_t>(MF_E_HW_MFT_FAILED_START_STREAMING),
              "MF_E_HW_MFT_FAILED_START_STREAMING");
static_assert(kErrorRecordingPreempted == static_cast<uint32_t>(MF_E_VIDEO_RECORDING_DEVICE_PREEMPTED),
              "MF_E_VIDEO_RECORDING_DEVICE_PREEMPTED");

// Windows N and KN ship without Media Foundation. The plugin delay-loads it so
// that the wallet still starts there, which makes this check required before
// the first call into it: a missing DLL would otherwise raise an exception.
bool MediaFoundationIsInstalled() {
  for (const wchar_t* library : {L"mfplat.dll", L"mf.dll", L"mfreadwrite.dll"}) {
    if (LoadLibraryExW(library, nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32) == nullptr) return false;
  }
  return true;
}

}  // namespace

CameraStatus Camera::StatusOf(HRESULT result) {
  error_code_.store(static_cast<uint32_t>(result));
  return StatusOfError(static_cast<uint32_t>(result));
}

std::string Camera::ErrorDetail() const {
  const uint32_t code = error_code_.load();
  return code == 0 ? std::string() : HresultText(code);
}

CameraStatus Camera::Open() {
  Release();
  failure_.store(CameraStatus::kOk);
  error_code_.store(0);

  if (!MediaFoundationIsInstalled()) return CameraStatus::kMediaUnavailable;

  const HRESULT started = MFStartup(MF_VERSION);
  if (FAILED(started)) return StatusOf(started);
  media_foundation_started_ = true;

  const CameraStatus status = OpenFirstDevice();
  if (status == CameraStatus::kOk) {
    // A size tried on the way here may have been refused.
    error_code_.store(0);
  } else {
    Release();
  }
  return status;
}

CameraStatus Camera::OpenFirstDevice() {
  ComPtr<IMFAttributes> search;
  HRESULT result = MFCreateAttributes(&search, 1);
  if (FAILED(result)) return StatusOf(result);
  result = search->SetGUID(MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE, MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID);
  if (FAILED(result)) return StatusOf(result);

  IMFActivate** devices = nullptr;
  UINT32 count = 0;
  result = MFEnumDeviceSources(search.Get(), &devices, &count);
  if (FAILED(result)) return StatusOf(result);
  if (count == 0) {
    CoTaskMemFree(devices);
    return CameraStatus::kNoCamera;
  }

  result = devices[0]->ActivateObject(IID_PPV_ARGS(&source_));
  for (UINT32 i = 0; i < count; i++) devices[i]->Release();
  CoTaskMemFree(devices);
  if (FAILED(result)) return StatusOf(result);

  // Lets the reader deinterlace. It does not turn one YUV format into another,
  // so ChooseFormat asks only for formats this package reads. The reader adds a
  // decoder by itself for a compressed format such as MJPEG.
  ComPtr<IMFAttributes> reader_settings;
  result = MFCreateAttributes(&reader_settings, 1);
  if (FAILED(result)) return StatusOf(result);
  result = reader_settings->SetUINT32(MF_SOURCE_READER_ENABLE_VIDEO_PROCESSING, TRUE);
  if (FAILED(result)) return StatusOf(result);

  result = MFCreateSourceReaderFromMediaSource(source_.Get(), reader_settings.Get(), &reader_);
  if (FAILED(result)) return StatusOf(result);

  return ChooseFormat();
}

CameraStatus Camera::ChooseFormat() {
  std::vector<FrameSize> offered;
  for (DWORD i = 0;; i++) {
    ComPtr<IMFMediaType> candidate;
    if (FAILED(reader_->GetNativeMediaType(kVideoStream, i, &candidate))) break;

    UINT32 width = 0;
    UINT32 height = 0;
    if (FAILED(MFGetAttributeSize(candidate.Get(), MF_MT_FRAME_SIZE, &width, &height))) continue;
    offered.push_back({width, height});
  }

  for (const FrameSize& size : SizesNearestWanted(offered)) {
    for (const PixelFormat format : {PixelFormat::kYuy2, PixelFormat::kNv12}) {
      const CameraStatus status = TryFormat(format, size.width, size.height);
      if (status != CameraStatus::kUnsupported) return status;
    }
  }
  return CameraStatus::kUnsupported;
}

CameraStatus Camera::TryFormat(PixelFormat format, uint32_t wanted_width, uint32_t wanted_height) {
  const bool is_nv12 = format == PixelFormat::kNv12;
  // NV12 shares color between two rows, so it needs an even number of them.
  if (is_nv12 && wanted_height % 2 != 0) return CameraStatus::kUnsupported;
  const GUID wanted_subtype = is_nv12 ? MFVideoFormat_NV12 : MFVideoFormat_YUY2;

  ComPtr<IMFMediaType> wanted;
  HRESULT result = MFCreateMediaType(&wanted);
  if (FAILED(result)) return StatusOf(result);
  result = wanted->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  if (FAILED(result)) return StatusOf(result);
  result = wanted->SetGUID(MF_MT_SUBTYPE, wanted_subtype);
  if (FAILED(result)) return StatusOf(result);
  result = MFSetAttributeSize(wanted.Get(), MF_MT_FRAME_SIZE, wanted_width, wanted_height);
  if (FAILED(result)) return StatusOf(result);

  result = reader_->SetCurrentMediaType(kVideoStream, nullptr, wanted.Get());
  if (FAILED(result)) {
    error_code_.store(static_cast<uint32_t>(result));
    return StatusOfRejectedFormat(static_cast<uint32_t>(result));
  }

  uint32_t width = 0;
  uint32_t height = 0;
  size_t stride = 0;
  const CameraStatus status = ReadCurrentFormat(format, &width, &height, &stride);
  if (status != CameraStatus::kOk) return status;

  pixel_format_ = format;
  width_ = width;
  height_ = height;
  stride_ = stride;
  return CameraStatus::kOk;
}

// What the driver actually agreed to, which is what frames will hold.
CameraStatus Camera::ReadCurrentFormat(PixelFormat format, uint32_t* width_out, uint32_t* height_out,
                                       size_t* stride_out) {
  const bool is_nv12 = format == PixelFormat::kNv12;
  ComPtr<IMFMediaType> current;
  const HRESULT result = reader_->GetCurrentMediaType(kVideoStream, &current);
  if (FAILED(result)) return StatusOf(result);

  GUID subtype = GUID_NULL;
  if (FAILED(current->GetGUID(MF_MT_SUBTYPE, &subtype)) ||
      subtype != (is_nv12 ? MFVideoFormat_NV12 : MFVideoFormat_YUY2)) {
    return CameraStatus::kUnsupported;
  }
  UINT32 width = 0;
  UINT32 height = 0;
  if (FAILED(MFGetAttributeSize(current.Get(), MF_MT_FRAME_SIZE, &width, &height))) return CameraStatus::kUnsupported;
  if (!IsReadableFrameSize(width, height) || (is_nv12 && height % 2 != 0)) return CameraStatus::kUnsupported;

  // Without a stated stride, a YUY2 row is two bytes a pixel and an NV12 row
  // one. A negative stride would mean a bottom-up picture, which neither is.
  const size_t row_bytes = static_cast<size_t>(width) * (is_nv12 ? size_t{1} : size_t{2});
  size_t stride = row_bytes;
  UINT32 stated = 0;
  if (SUCCEEDED(current->GetUINT32(MF_MT_DEFAULT_STRIDE, &stated))) {
    if (stated == 0) return CameraStatus::kUnsupported;
    stride = UsableStride(static_cast<INT32>(stated), row_bytes);
    if (stride == 0) return CameraStatus::kUnsupported;
  }

  *width_out = width;
  *height_out = height;
  *stride_out = stride;
  return CameraStatus::kOk;
}

void Camera::Release() {
  streaming_.store(false);
  // Ends a ReadSample that is waiting on a stalled camera, so the join below
  // cannot hang the app.
  if (source_) source_->Shutdown();
  if (capture_thread_.joinable()) capture_thread_.join();
  frame_callback_ = nullptr;

  {
    std::lock_guard<std::mutex> lock(frame_mutex_);
    newest_luma_.clear();
  }

  reader_.Reset();
  source_.Reset();
  if (media_foundation_started_) {
    MFShutdown();
    media_foundation_started_ = false;
  }
  width_ = 0;
  height_ = 0;
  stride_ = 0;
}

void Camera::CaptureLoop() {
  const size_t pixels = static_cast<size_t>(width_) * height_;
  std::vector<uint8_t> rgba(pixels * 4);
  std::vector<uint8_t> luma(pixels);
  UnreadableFrames unreadable;

  while (streaming_.load()) {
    DWORD stream = 0;
    DWORD flags = 0;
    LONGLONG timestamp = 0;
    ComPtr<IMFSample> sample;
    const HRESULT result = reader_->ReadSample(kVideoStream, 0, &stream, &flags, &timestamp, &sample);

    if (FAILED(result)) {
      if (streaming_.load()) {
        error_code_.store(static_cast<uint32_t>(result));
        failure_.store(StatusOfStreamError(static_cast<uint32_t>(result)));
      }
      break;
    }
    if (flags & (MF_SOURCE_READERF_ERROR | MF_SOURCE_READERF_ENDOFSTREAM)) {
      if (streaming_.load()) failure_.store(CameraStatus::kStopped);
      break;
    }
    if (flags & MF_SOURCE_READERF_CURRENTMEDIATYPECHANGED) {
      // A new row length can be followed. The buffers and the texture are sized
      // for this frame size, so a new one is reported instead of misdrawn.
      uint32_t width = 0;
      uint32_t height = 0;
      size_t stride = 0;
      const CameraStatus status = ReadCurrentFormat(pixel_format_, &width, &height, &stride);
      if (status != CameraStatus::kOk || width != width_ || height != height_) {
        if (streaming_.load()) failure_.store(status == CameraStatus::kOk ? CameraStatus::kUnsupported : status);
        break;
      }
      stride_ = stride;
    }
    if (!sample) continue;

    bool converted = false;
    ComPtr<IMFMediaBuffer> buffer;
    if (SUCCEEDED(sample->ConvertToContiguousBuffer(&buffer)) && buffer) {
      BYTE* data = nullptr;
      DWORD capacity = 0;
      DWORD length = 0;
      if (SUCCEEDED(buffer->Lock(&data, &capacity, &length))) {
        converted =
            pixel_format_ == PixelFormat::kNv12
                ? ConvertNv12(data, length, stride_, width_, height_, rgba.data(), rgba.size(), luma.data(), luma.size())
                : ConvertYuy2(data, length, stride_, width_, height_, rgba.data(), rgba.size(), luma.data(), luma.size());
        buffer->Unlock();
      }
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

}  // namespace desktop_qr_camera
