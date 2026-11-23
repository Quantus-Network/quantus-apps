#include "desktop_qr_camera_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <utility>
#include <vector>

namespace desktop_qr_camera {

// static
void DesktopQrCameraPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "desktop_qr_camera", &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<DesktopQrCameraPlugin>(registrar->texture_registrar());

  channel->SetMethodCallHandler([plugin_pointer = plugin.get()](const auto& call, auto result) {
    plugin_pointer->HandleMethodCall(call, std::move(result));
  });

  registrar->AddPlugin(std::move(plugin));
}

DesktopQrCameraPlugin::DesktopQrCameraPlugin(flutter::TextureRegistrar* texture_registrar)
    : texture_registrar_(texture_registrar) {}

DesktopQrCameraPlugin::~DesktopQrCameraPlugin() { ReleaseCamera(); }

void DesktopQrCameraPlugin::ReleaseCamera() {
  // The capture thread ends first, so no frame can reach a texture being torn
  // down.
  camera_.Release();
  if (texture_handler_) {
    TextureHandler::Retire(std::move(texture_handler_));
  }
}

void DesktopQrCameraPlugin::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
                                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "open") {
    ReleaseCamera();
    const CameraStatus status = camera_.Open();
    if (status == CameraStatus::kOk) {
      result->Success();
    } else {
      result->Error(CameraStatusCode(status));
    }
  } else if (method == "startPreview") {
    auto handler = std::make_shared<TextureHandler>(texture_registrar_);
    const int64_t texture_id = handler->RegisterTexture();
    if (texture_id < 0) {
      result->Error(CameraStatusCode(CameraStatus::kFailed), "Failed to register texture");
      return;
    }

    TextureHandler* frames = handler.get();
    const bool started = camera_.StartCaptureLoop([frames](const uint8_t* rgba, uint32_t width, uint32_t height) {
      frames->UpdateBuffer(rgba, static_cast<int>(width), static_cast<int>(height));
    });
    if (!started) {
      TextureHandler::Retire(std::move(handler));
      result->Error(CameraStatusCode(CameraStatus::kFailed), "The camera is not open");
      return;
    }

    texture_handler_ = std::move(handler);
    result->Success(flutter::EncodableValue(texture_id));
  } else if (method == "captureFrame") {
    LumaFrame frame = camera_.CaptureFrame();
    if (frame.status != CameraStatus::kOk) {
      result->Error(CameraStatusCode(frame.status));
    } else if (frame.luma.empty()) {
      result->Success();
    } else {
      flutter::EncodableMap answer;
      answer[flutter::EncodableValue("width")] = flutter::EncodableValue(static_cast<int32_t>(frame.width));
      answer[flutter::EncodableValue("height")] = flutter::EncodableValue(static_cast<int32_t>(frame.height));
      answer[flutter::EncodableValue("luma")] = flutter::EncodableValue(std::move(frame.luma));
      result->Success(flutter::EncodableValue(std::move(answer)));
    }
  } else if (method == "release") {
    ReleaseCamera();
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace desktop_qr_camera
