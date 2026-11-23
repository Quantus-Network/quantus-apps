#ifndef FLUTTER_PLUGIN_DESKTOP_QR_CAMERA_PLUGIN_H_
#define FLUTTER_PLUGIN_DESKTOP_QR_CAMERA_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <memory>

#include "camera.h"
#include "texture_handler.h"

namespace desktop_qr_camera {

class DesktopQrCameraPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit DesktopQrCameraPlugin(flutter::TextureRegistrar* texture_registrar);

  virtual ~DesktopQrCameraPlugin();

  // Disallow copy and assign.
  DesktopQrCameraPlugin(const DesktopQrCameraPlugin&) = delete;
  DesktopQrCameraPlugin& operator=(const DesktopQrCameraPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  void ReleaseCamera();

  Camera camera_;
  flutter::TextureRegistrar* texture_registrar_;
  std::unique_ptr<TextureHandler> texture_handler_;
};

}  // namespace desktop_qr_camera

#endif  // FLUTTER_PLUGIN_DESKTOP_QR_CAMERA_PLUGIN_H_
