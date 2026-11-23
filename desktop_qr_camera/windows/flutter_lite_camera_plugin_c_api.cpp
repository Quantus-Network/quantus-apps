#include "include/flutter_lite_camera/flutter_lite_camera_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_lite_camera_plugin.h"

void FlutterLiteCameraPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_lite_camera::FlutterLiteCameraPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
