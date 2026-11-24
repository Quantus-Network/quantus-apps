#include "include/desktop_qr_camera/desktop_qr_camera_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "desktop_qr_camera_plugin.h"

void DesktopQrCameraPluginCApiRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  desktop_qr_camera::DesktopQrCameraPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
