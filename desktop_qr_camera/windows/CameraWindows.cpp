#include "camera.h"

#include <cstdint>
#include <initializer_list>
#include <limits>
#include <utility>

#include "yuy2.h"

using Microsoft::WRL::ComPtr;

namespace desktop_qr_camera {

namespace {

constexpr DWORD kVideoStream = static_cast<DWORD>(MF_SOURCE_READER_FIRST_VIDEO_STREAM);
constexpr int64_t kWantedWidth = 1280;
constexpr int64_t kWantedHeight = 720;

CameraStatus StatusOf(HRESULT result) {
  if (result == E_ACCESSDENIED) return CameraStatus::kPermissionDenied;
  if (result == HRESULT_FROM_WIN32(ERROR_SHARING_VIOLATION) || result == HRESULT_FROM_WIN32(ERROR_BUSY)) {
    return CameraStatus::kBusy;
  }
  return CameraStatus::kFailed;
}

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

CameraStatus Camera::Open() {
  Release();
  failure_.store(CameraStatus::kOk);

  if (!MediaFoundationIsInstalled()) return CameraStatus::kMediaUnavailable;

  const HRESULT started = MFStartup(MF_VERSION);
  if (FAILED(started)) return StatusOf(started);
  media_foundation_started_ = true;

  const CameraStatus status = OpenFirstDevice();
  if (status != CameraStatus::kOk) Release();
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

  // Lets the reader convert a camera's own format, such as MJPEG or NV12, to
  // the YUY2 this package reads.
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
  UINT32 best_width = 0;
  UINT32 best_height = 0;
  int64_t best_distance = (std::numeric_limits<int64_t>::max)();
  for (DWORD i = 0;; i++) {
    ComPtr<IMFMediaType> candidate;
    if (FAILED(reader_->GetNativeMediaType(kVideoStream, i, &candidate))) break;

    UINT32 width = 0;
    UINT32 height = 0;
    if (FAILED(MFGetAttributeSize(candidate.Get(), MF_MT_FRAME_SIZE, &width, &height))) continue;
    if (width == 0 || height == 0 || width > kMaxFrameSide || height > kMaxFrameSide || width % 2 != 0) continue;

    const int64_t across = static_cast<int64_t>(width) - kWantedWidth;
    const int64_t down = static_cast<int64_t>(height) - kWantedHeight;
    const int64_t distance = (across < 0 ? -across : across) + (down < 0 ? -down : down);
    if (distance < best_distance) {
      best_distance = distance;
      best_width = width;
      best_height = height;
    }
  }
  if (best_width == 0) return CameraStatus::kUnsupported;

  ComPtr<IMFMediaType> wanted;
  HRESULT result = MFCreateMediaType(&wanted);
  if (FAILED(result)) return StatusOf(result);
  result = wanted->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  if (FAILED(result)) return StatusOf(result);
  result = wanted->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_YUY2);
  if (FAILED(result)) return StatusOf(result);
  result = MFSetAttributeSize(wanted.Get(), MF_MT_FRAME_SIZE, best_width, best_height);
  if (FAILED(result)) return StatusOf(result);

  result = reader_->SetCurrentMediaType(kVideoStream, nullptr, wanted.Get());
  if (result == E_ACCESSDENIED || result == HRESULT_FROM_WIN32(ERROR_SHARING_VIOLATION)) return StatusOf(result);
  if (FAILED(result)) return CameraStatus::kUnsupported;

  // What the driver actually agreed to, which is what frames will hold.
  ComPtr<IMFMediaType> current;
  result = reader_->GetCurrentMediaType(kVideoStream, &current);
  if (FAILED(result)) return StatusOf(result);

  GUID subtype = GUID_NULL;
  if (FAILED(current->GetGUID(MF_MT_SUBTYPE, &subtype)) || subtype != MFVideoFormat_YUY2) {
    return CameraStatus::kUnsupported;
  }
  UINT32 width = 0;
  UINT32 height = 0;
  if (FAILED(MFGetAttributeSize(current.Get(), MF_MT_FRAME_SIZE, &width, &height))) return CameraStatus::kUnsupported;
  if (width == 0 || height == 0 || width > kMaxFrameSide || height > kMaxFrameSide || width % 2 != 0) {
    return CameraStatus::kUnsupported;
  }

  // YUY2 is packed, so without a stated stride a row is two bytes a pixel. A
  // negative stride would mean a bottom-up picture, which YUY2 never is.
  size_t stride = static_cast<size_t>(width) * 2;
  UINT32 stated = 0;
  if (SUCCEEDED(current->GetUINT32(MF_MT_DEFAULT_STRIDE, &stated))) {
    const INT32 signed_stride = static_cast<INT32>(stated);
    if (signed_stride <= 0) return CameraStatus::kUnsupported;
    stride = static_cast<size_t>(signed_stride);
  }

  width_ = width;
  height_ = height;
  stride_ = stride;
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

bool Camera::StartCaptureLoop(FrameCallback callback) {
  if (!reader_ || streaming_.load()) return false;
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

  while (streaming_.load()) {
    DWORD stream = 0;
    DWORD flags = 0;
    LONGLONG timestamp = 0;
    ComPtr<IMFSample> sample;
    const HRESULT result = reader_->ReadSample(kVideoStream, 0, &stream, &flags, &timestamp, &sample);

    if (FAILED(result)) {
      if (streaming_.load()) {
        const CameraStatus status = StatusOf(result);
        failure_.store(status == CameraStatus::kFailed ? CameraStatus::kStopped : status);
      }
      break;
    }
    if (flags & (MF_SOURCE_READERF_ERROR | MF_SOURCE_READERF_ENDOFSTREAM)) {
      if (streaming_.load()) failure_.store(CameraStatus::kStopped);
      break;
    }
    if (!sample) continue;

    ComPtr<IMFMediaBuffer> buffer;
    if (FAILED(sample->ConvertToContiguousBuffer(&buffer)) || !buffer) continue;

    BYTE* data = nullptr;
    DWORD capacity = 0;
    DWORD length = 0;
    if (FAILED(buffer->Lock(&data, &capacity, &length))) continue;
    const bool converted =
        ConvertYuy2(data, length, stride_, width_, height_, rgba.data(), rgba.size(), luma.data(), luma.size());
    buffer->Unlock();
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
